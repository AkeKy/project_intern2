import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import type { GeoJsonGeometry } from './copernicus.service';

// ── Type definitions ────────────────────────────────────────────────────────

export interface AgroMonitoringImage {
  dt: number;
  type: string;
  image: {
    url: string;
  };
  ndvi?: string;
}

interface AgroPolygonResponse {
  id: string;
}

// ── Service ─────────────────────────────────────────────────────────────────

@Injectable()
export class AgroMonitoringService {
  private readonly logger = new Logger(AgroMonitoringService.name);
  private readonly apiKey: string;
  private readonly baseUrl = 'http://api.agromonitoring.com/agro/1.0';

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
  ) {
    this.apiKey =
      this.configService.get<string>('AGROMONITORING_API_KEY') || '';
    if (!this.apiKey) {
      this.logger.warn(
        'AGROMONITORING_API_KEY is not defined in the environment variables.',
      );
    }
  }

  /**
   * Register a plot (GeoJSON polygon) with AgroMonitoring to get a polyid.
   * @param name Name of the plot
   * @param geojson Geometry of the plot in GeoJSON format
   * @returns The generated polyid from AgroMonitoring
   */
  async createPolygon(name: string, geojson: GeoJsonGeometry): Promise<string> {
    try {
      this.logger.debug(`Registering polygon '${name}' with AgroMonitoring...`);
      const payload = {
        name: name,
        geo_json: {
          type: 'Feature',
          properties: {},
          geometry: geojson,
        },
      };

      const { data } = await firstValueFrom(
        this.httpService.post<AgroPolygonResponse>(
          `${this.baseUrl}/polygons?appid=${this.apiKey}&duplicated=true`,
          payload,
        ),
      );

      this.logger.debug(`Polygon registered successfully. PolyId: ${data.id}`);
      return data.id;
    } catch (error: unknown) {
      const errMsg = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(
        'Failed to register polygon with AgroMonitoring',
        errMsg,
      );
      throw new HttpException(
        'Failed to register polygon with Agromonitoring',
        HttpStatus.BAD_GATEWAY,
      );
    }
  }

  /**
   * Fetch available satellite imagery data (date + urls) for a registered polygon.
   * @param polyid The AgroMonitoring polygon ID
   * @param start Start timestamp (unix timestamp)
   * @param end End timestamp (unix timestamp)
   */
  async getImagery(
    polyid: string,
    start: number,
    end: number,
  ): Promise<AgroMonitoringImage[]> {
    try {
      this.logger.debug(
        `Fetching imagery for polyid '${polyid}' from ${start} to ${end}...`,
      );

      const { data } = await firstValueFrom(
        this.httpService.get<AgroMonitoringImage[]>(
          `${this.baseUrl}/image/search`,
          {
            params: {
              polyid,
              start,
              end,
              appid: this.apiKey,
            },
          },
        ),
      );

      return data;
    } catch (error: unknown) {
      const errMsg = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error('Failed to fetch imagery from AgroMonitoring', errMsg);
      throw new HttpException(
        'Failed to fetch satellite imagery',
        HttpStatus.BAD_GATEWAY,
      );
    }
  }
}
