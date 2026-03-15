import {
  Injectable,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CopernicusService, type GeoJsonGeometry } from './copernicus.service';

// ── Type definitions ────────────────────────────────────────────────────────

interface PlotGeometryRow {
  id: string;
  geometry_geojson: string;
}

export interface LayerInfo {
  layerType: string;
  baseUrl: string;
}

// ── Service ─────────────────────────────────────────────────────────────────

@Injectable()
export class MapTilesService {
  private readonly logger = new Logger(MapTilesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly copernicusService: CopernicusService,
  ) {}

  /**
   * Fetch available satellite imagery dates from Copernicus Catalog API for a given plot.
   */
  async getAvailableDates(plotId: string): Promise<string[]> {
    const plotRows = await this.prisma.$queryRaw<PlotGeometryRow[]>`
      SELECT id, ST_AsGeoJSON(geometry) as "geometry_geojson" 
      FROM plots 
      WHERE id = ${plotId}
    `;

    if (!plotRows.length || !plotRows[0].geometry_geojson) {
      throw new NotFoundException('Plot or geometry not found');
    }

    const geometry = JSON.parse(
      plotRows[0].geometry_geojson,
    ) as GeoJsonGeometry;

    // Fetch the latest carbon record for this plot to get the crop cycle dates
    const latestRecord = await this.prisma.carbonRecord.findFirst({
      where: { plotId: plotId },
      orderBy: { createdAt: 'desc' },
    });

    let startDate: string;
    let endDate: string;

    if (latestRecord?.startDate && latestRecord?.harvestDate) {
      startDate = latestRecord.startDate.toISOString();
      endDate = latestRecord.harvestDate.toISOString();
    } else {
      // Fallback to last 6 months if no dates are provided
      endDate = new Date().toISOString();
      startDate = new Date(
        Date.now() - 180 * 24 * 60 * 60 * 1000,
      ).toISOString();
    }

    // Pass GeoJSON and dates to Copernicus Service to search catalog
    return this.copernicusService.getAvailableDates(
      geometry,
      startDate,
      endDate,
    );
  }

  /**
   * Return the layer metadata mapped for the frontend App.
   */
  async getLayersForDate(
    plotId: string,
    dateStr: string,
  ): Promise<LayerInfo[]> {
    const plot = await this.prisma.plot.findUnique({ where: { id: plotId } });
    if (!plot) throw new NotFoundException('Plot not found');

    const targetDateStr = dateStr.split('T')[0];

    const results: LayerInfo[] = [
      {
        layerType: 'RGB',
        baseUrl: `/proxy/${plotId}/${targetDateStr}/RGB`,
      },
      {
        layerType: 'NDVI',
        baseUrl: `/proxy/${plotId}/${targetDateStr}/NDVI`,
      },
    ];

    return results;
  }

  /**
   * Fetch actual PNG tile from Copernicus Process API
   */
  async getProxyTile(
    plotId: string,
    dateStr: string,
    layerType: 'RGB' | 'NDVI',
    z: number,
    x: number,
    y: number,
  ): Promise<ArrayBuffer> {
    const plot = await this.prisma.plot.findUnique({ where: { id: plotId } });
    if (!plot) throw new NotFoundException('Plot not found');

    return this.copernicusService.getTileImage(dateStr, layerType, z, x, y);
  }
}
