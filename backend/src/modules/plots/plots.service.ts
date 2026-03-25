import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CopernicusService,
  type GeoJsonGeometry,
} from '../map-tiles/copernicus.service';
import { CreatePlotDto } from './dto/create-plot.dto';
import { Prisma } from '@prisma/client';

// ── Type definitions ────────────────────────────────────────────────────────

export interface PlotRow {
  id: string;
  plot_name: string;
  area_ha: number;
  area_rai: number;
  plot_type: string;
  site_id: string;
  irrigation_source: string;
  geometry?: string;
}

interface PlotGeometryRow {
  id: string;
  geometry_geojson: string;
}

export interface NdviHistoryRecord {
  id: string;
  plotId: string;
  date: Date;
  mean: number;
  max: number;
  min: number;
  cloudCover: number | null;
  createdAt: Date;
}

// ── Service ─────────────────────────────────────────────────────────────────

@Injectable()
export class PlotsService {
  private readonly logger = new Logger(PlotsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly copernicusService: CopernicusService,
  ) {}

  /**
   * Create a new plot with PostGIS area calculation
   */
  async create(createPlotDto: CreatePlotDto) {
    const { farmId, plotName, plotType, coordinates, siteId } = createPlotDto;

    // Convert coordinates to GeoJSON polygon
    const polygonCoordinates = coordinates.map((c) => [c.lng, c.lat]);

    // Close the polygon ring if needed
    const first = polygonCoordinates[0];
    const last = polygonCoordinates[polygonCoordinates.length - 1];
    if (first[0] !== last[0] || first[1] !== last[1]) {
      polygonCoordinates.push([...first]);
    }

    const geoJsonString = JSON.stringify({
      type: 'Polygon',
      coordinates: [polygonCoordinates],
    });

    // Insert with PostGIS area calculation
    const query = Prisma.sql`
      INSERT INTO "plots" (
        "id", "farm_id", "plot_name", "plot_type", "geometry",
        "area_ha", "area_rai", "site_id", "irrigation_source", "created_at", "updated_at"
      )
      VALUES (
        gen_random_uuid(),
        ${farmId},
        ${plotName},
        ${plotType},
        ST_SetSRID(ST_GeomFromGeoJSON(${geoJsonString}), 4326),
        ST_Area(ST_GeomFromGeoJSON(${geoJsonString})::geography) / 10000,
        ST_Area(ST_GeomFromGeoJSON(${geoJsonString})::geography) / 1600,
        ${siteId},
        'AWD',
        NOW(),
        NOW()
      )
      RETURNING id, plot_name, area_ha, area_rai, plot_type, site_id, irrigation_source;
    `;

    const result = await this.prisma.$queryRaw<PlotRow[]>(query);
    return result[0];
  }

  /**
   * Get all plots with parsed geometry
   */
  async findAll() {
    const plots = await this.prisma.$queryRaw<PlotRow[]>`
      SELECT id, plot_name, area_rai, plot_type,
             ST_AsGeoJSON(geometry) as geometry
      FROM "plots";
    `;

    return plots.map((plot) => ({
      ...plot,
      geometry: plot.geometry
        ? (JSON.parse(plot.geometry) as Record<string, unknown>)
        : null,
    }));
  }

  /**
   * Get plots filtered by site ID
   */
  async findBySite(siteId: string) {
    const plots = await this.prisma.$queryRaw<PlotRow[]>`
      SELECT id, plot_name, area_rai, plot_type,
             ST_AsGeoJSON(geometry) as geometry
      FROM "plots"
      WHERE "site_id" = ${siteId};
    `;

    return plots.map((plot) => ({
      ...plot,
      geometry: plot.geometry
        ? (JSON.parse(plot.geometry) as Record<string, unknown>)
        : null,
    }));
  }

  /**
   * Fetch historical NDVI data for a plot, using a DB cache
   */
  async getNdviHistory(plotId: string): Promise<NdviHistoryRecord[]> {
    // 1. Get plot and geojson
    const plotRows = await this.prisma.$queryRaw<PlotGeometryRow[]>`
      SELECT id, ST_AsGeoJSON(geometry) as "geometry_geojson" 
      FROM plots 
      WHERE id = ${plotId}
    `;

    if (!plotRows.length || !plotRows[0].geometry_geojson) {
      throw new Error('Plot or geometry not found');
    }
    const geometry = JSON.parse(
      plotRows[0].geometry_geojson,
    ) as GeoJsonGeometry;

    // 2. Get the date range (from CarbonRecord or last 180 days)
    const latestRecord = await this.prisma.carbonRecord.findFirst({
      where: { plotId },
      orderBy: { createdAt: 'desc' },
    });

    let startDate: Date;
    let endDate: Date;

    // endDate must never exceed today — Copernicus has no future imagery
    const today = new Date();

    if (latestRecord?.startDate && latestRecord?.harvestDate) {
      // Use crop cycle dates but clamp endDate to today
      startDate = latestRecord.startDate;
      endDate =
        latestRecord.harvestDate > today ? today : latestRecord.harvestDate;
    } else {
      endDate = today;
      startDate = new Date(Date.now() - 180 * 24 * 60 * 60 * 1000);
    }

    // Ensure we have at least 180 days of data to query for historical context
    const minRange = 180 * 24 * 60 * 60 * 1000;
    if (endDate.getTime() - startDate.getTime() < minRange) {
      startDate = new Date(endDate.getTime() - minRange);
    }

    // 3. Search for cached records within this range
    const cachedHistory = await this.prisma.$queryRaw<NdviHistoryRecord[]>`
      SELECT id, plot_id AS "plotId", date, mean, max, min, 
             cloud_cover AS "cloudCover", created_at AS "createdAt"
      FROM plot_ndvi_history
      WHERE plot_id = ${plotId}
        AND date >= ${startDate}
        AND date <= ${endDate}
      ORDER BY date ASC
    `;

    // 4. Determine if we need to fetch fresh data
    const shouldFetch = this.shouldRefetchNdvi(
      cachedHistory,
      startDate,
      endDate,
    );

    if (shouldFetch) {
      try {
        const startTime = Date.now();
        const stats = await this.copernicusService.getNdviStatistics(
          geometry,
          startDate.toISOString().split('T')[0],
          endDate.toISOString().split('T')[0],
        );
        const duration = Date.now() - startTime;
        this.logger.log(`Fetched ${stats.length} NDVI stats in ${duration}ms`);

        if (stats.length > 0) {
          // Upsert stats into database
          for (const stat of stats) {
            const statDate = new Date(stat.date);
            await this.prisma.$executeRaw`
              INSERT INTO plot_ndvi_history (id, plot_id, date, mean, max, min, cloud_cover, created_at)
              VALUES (gen_random_uuid(), ${plotId}, ${statDate}, ${stat.mean}, ${stat.max}, ${stat.min}, ${stat.cloudCover}, NOW())
              ON CONFLICT (plot_id, date) 
              DO UPDATE SET mean = ${stat.mean}, max = ${stat.max}, min = ${stat.min}, cloud_cover = ${stat.cloudCover}
            `;
          }
        }
      } catch (error: unknown) {
        const errMsg = error instanceof Error ? error.message : 'Unknown error';
        this.logger.error(
          `Failed to fetch NDVI stats for plot ${plotId}: ${errMsg}`,
        );
        if (error instanceof Error && 'response' in error) {
          let details = '';
          if ((error as any).response?.data) {
            details = JSON.stringify((error as any).response?.data || {});
          }
          this.logger.error(
            `Copernicus API response: status=${(error as any).response?.status}, data=${details}`,
          );
        }
      }
    }

    const finalHistory = await this.prisma.$queryRaw<NdviHistoryRecord[]>`
      SELECT id, plot_id AS "plotId", date, mean, max, min,
             cloud_cover AS "cloudCover", created_at AS "createdAt"
      FROM plot_ndvi_history
      WHERE plot_id = ${plotId}
        AND date >= ${startDate}
        AND date <= ${endDate}
      ORDER BY date ASC
    `;

    return this.smoothNdviHistory(finalHistory);
  }

  /**
   * Smooth NDVI data to remove noise from clouds
   */
  private smoothNdviHistory(records: NdviHistoryRecord[]): NdviHistoryRecord[] {
    if (records.length === 0) return records;

    // 1. Strict Filtering: Only keep data with < 15% cloudy pixels.
    // Cloud cover is now a ratio (0.0 = clear, 1.0 = fully cloudy) from SCL-based detection.
    const base = records.filter((r) => (r.cloudCover ?? 0) < 0.15);

    if (base.length < 3) return base;

    // 2. Simple Moving Average (window of 3) to further remove noise
    return base.map((record, i, arr) => {
      if (i === 0 || i === arr.length - 1) return record;

      const prev = arr[i - 1];
      const next = arr[i + 1];

      // Average the values over 3 points
      return {
        ...record,
        mean: (prev.mean + record.mean + next.mean) / 3,
        max: (prev.max + record.max + next.max) / 3,
        min: (prev.min + record.min + next.min) / 3,
      };
    });
  }

  /**
   * Determine if we should re-fetch NDVI data from Copernicus
   */
  private shouldRefetchNdvi(
    cachedHistory: NdviHistoryRecord[],
    startDate: Date,
    endDate: Date,
  ): boolean {
    const ONE_DAY_MS = 24 * 60 * 60 * 1000;

    if (cachedHistory.length === 0) {
      return true;
    }

    // Check if the cache is missing historical data we now want
    const earliestCachedDate = new Date(cachedHistory[0].date);
    const isMissingHistory =
      earliestCachedDate.getTime() > startDate.getTime() + ONE_DAY_MS;

    const latestCachedInsert =
      cachedHistory[cachedHistory.length - 1].createdAt;
    const isOutdated = Date.now() - latestCachedInsert.getTime() > ONE_DAY_MS;

    // Fetch if cache is missing history OR if current cycle is still active and cache is old
    const needsFreshUpdate =
      endDate.getTime() >= Date.now() - ONE_DAY_MS && isOutdated;

    return isMissingHistory || needsFreshUpdate;
  }
}
