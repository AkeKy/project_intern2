import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';

// ── Type definitions ────────────────────────────────────────────────────────

interface CopernicusTokenResponse {
  access_token: string;
  expires_in: number;
}

interface CatalogFeature {
  properties?: {
    datetime?: string;
    'eo:cloud_cover'?: number;
  };
}

interface CatalogSearchResponse {
  features?: CatalogFeature[];
}

interface NdviBandStats {
  sampleCount: number;
  mean: number;
  max: number;
  min: number;
}

interface StatisticalInterval {
  interval?: {
    from?: string;
  };
  outputs?: {
    [key: string]: {
      bands?: {
        B0?: {
          stats?: NdviBandStats;
        };
      };
    };
  };
}

interface StatisticalResponse {
  data?: StatisticalInterval[];
}

export interface NdviStatRecord {
  date: string;
  mean: number;
  max: number;
  min: number;
  cloudCover: number | null;
}

export interface GeoJsonGeometry {
  type: string;
  coordinates: number[][][] | number[][][][];
}

// ── Service ─────────────────────────────────────────────────────────────────

@Injectable()
export class CopernicusService {
  private readonly logger = new Logger(CopernicusService.name);
  private token: string | null = null;
  private tokenExpiresAt = 0;

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
  ) {}

  /**
   * Fetch OAuth 2.0 Access Token from Copernicus Data Space
   */
  private async getAuthToken(): Promise<string> {
    if (this.token && Date.now() < this.tokenExpiresAt) {
      return this.token;
    }

    const username = this.configService.get<string>('COPERNICUS_USERNAME');
    const password = this.configService.get<string>('COPERNICUS_PASSWORD');

    if (!username || !password) {
      this.logger.error('Copernicus credentials are not configured in .env');
      throw new HttpException(
        'Satellite imagery service is not configured',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }

    try {
      this.logger.debug('Fetching new Copernicus access token...');
      const params = new URLSearchParams();
      params.append('client_id', 'cdse-public');
      params.append('username', username);
      params.append('password', password);
      params.append('grant_type', 'password');

      const { data } = await firstValueFrom(
        this.httpService.post<CopernicusTokenResponse>(
          'https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token',
          params.toString(),
          {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          },
        ),
      );

      this.token = data.access_token;
      // Refresh 60 seconds before expiration
      this.tokenExpiresAt = Date.now() + (data.expires_in - 60) * 1000;
      this.logger.debug('Copernicus access token acquired successfully');

      return this.token;
    } catch (error: unknown) {
      const errMsg = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error('Failed to get Copernicus auth token', errMsg);
      throw new HttpException(
        'Failed to authenticate with Copernicus',
        HttpStatus.BAD_GATEWAY,
      );
    }
  }

  /**
   * Fetch available satellite imagery dates for a GeoJSON polygon
   */
  async getAvailableDates(
    geojson: GeoJsonGeometry | string,
    startDateInput?: string,
    endDateInput?: string,
  ): Promise<string[]> {
    const token = await this.getAuthToken();
    this.logger.debug('Searching Copernicus Catalog for available dates...');

    // Fetch last 6 months or use provided dates
    const endDate = endDateInput || new Date().toISOString();
    const startDate =
      startDateInput ||
      new Date(Date.now() - 180 * 24 * 60 * 60 * 1000).toISOString();

    const geometry =
      typeof geojson === 'string'
        ? (JSON.parse(geojson) as GeoJsonGeometry)
        : geojson;

    const payload = {
      intersects: geometry,
      datetime: `${startDate}/${endDate}`,
      collections: ['sentinel-2-l2a'],
      limit: 100,
    };

    try {
      const { data } = await firstValueFrom(
        this.httpService.post<CatalogSearchResponse>(
          'https://sh.dataspace.copernicus.eu/api/v1/catalog/1.0.0/search',
          payload,
          {
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${token}`,
            },
          },
        ),
      );

      // Extract unique dates from features, strictly < 15% cloud cover
      const datesSet = new Set<string>();
      if (data.features && data.features.length > 0) {
        const strictFeatures = data.features.filter(
          (f) => (f.properties?.['eo:cloud_cover'] ?? 100) < 15,
        );

        strictFeatures.forEach((feature: CatalogFeature) => {
          if (feature.properties?.datetime) {
            datesSet.add(feature.properties.datetime);
          }
        });
      }

      return Array.from(datesSet).sort((a, b) => b.localeCompare(a));
    } catch (error: unknown) {
      const errMsg = error instanceof Error ? error.message : 'Unknown error';
      let details = '';
      /* eslint-disable-next-line @typescript-eslint/no-unsafe-member-access */
      if ((error as any).response?.data) {
        /* eslint-disable-next-line @typescript-eslint/no-unsafe-member-access */
        details = JSON.stringify((error as any).response?.data || {});
      }
      this.logger.error(
        `Failed to fetch available dates: ${errMsg} ${details}`,
      );
      throw new HttpException(
        `Catalog Error: ${errMsg} ${details}`,
        HttpStatus.BAD_GATEWAY,
      );
    }
  }

  /**
   * Convert XYZ Web Mercator tile coordinates to WGS84 Bounding Box
   */
  private tile2boundingBox(
    x: number,
    y: number,
    z: number,
  ): [number, number, number, number] {
    const n = Math.pow(2, z);
    const lon_deg_left = (x / n) * 360.0 - 180.0;
    const lon_deg_right = ((x + 1) / n) * 360.0 - 180.0;
    const lat_rad_top = Math.atan(Math.sinh(Math.PI * (1 - (2 * y) / n)));
    const lat_rad_bottom = Math.atan(
      Math.sinh(Math.PI * (1 - (2 * (y + 1)) / n)),
    );
    const lat_deg_top = lat_rad_top * (180.0 / Math.PI);
    const lat_deg_bottom = lat_rad_bottom * (180.0 / Math.PI);

    // Process API expects [minX, minY, maxX, maxY]
    return [lon_deg_left, lat_deg_bottom, lon_deg_right, lat_deg_top];
  }

  /**
   * Fetch a specific Tile (PNG) from Copernicus Process API
   */
  async getTileImage(
    date: string,
    layerType: 'RGB' | 'NDVI',
    z: number,
    x: number,
    y: number,
  ): Promise<ArrayBuffer> {
    const token = await this.getAuthToken();
    const bbox = this.tile2boundingBox(x, y, z);
    const targetDate = date.split('T')[0];

    // Define Evalscript based on requested layer
    const evalscriptRGB = `
//VERSION=3
function setup() {
  return { input: ["B02", "B03", "B04", "dataMask"], output: { bands: 4 } };
}
const f = 2.5;
function evaluatePixel(sample) {
  if (sample.dataMask === 0) return [0,0,0,0];
  return [sample.B04 * f, sample.B03 * f, sample.B02 * f, 1];
}`;

    const evalscriptNDVI = `
//VERSION=3
function setup() {
  return { input: ["B04", "B08", "dataMask"], output: { bands: 4 } };
}
function evaluatePixel(sample) {
  let ndvi = (sample.B08 - sample.B04) / (sample.B08 + sample.B04);
  if (sample.dataMask === 0) return [0,0,0,0];
  
  if (ndvi < 0.1) return [0.8, 0, 0, 1]; // Red (Low health)
  if (ndvi < 0.3) return [1, 0.6, 0, 1]; // Orange
  if (ndvi < 0.5) return [1, 1, 0, 1]; // Yellow
  if (ndvi < 0.8) return [0.5, 1, 0, 1]; // Light green
  return [0, 0.8, 0, 1]; // Dark green (High health)
}`;

    const payload = {
      input: {
        bounds: {
          bbox: bbox,
          properties: { crs: 'http://www.opengis.net/def/crs/EPSG/0/4326' },
        },
        data: [
          {
            type: 'sentinel-2-l2a',
            dataFilter: {
              timeRange: {
                from: `${targetDate}T00:00:00Z`,
                to: `${targetDate}T23:59:59Z`,
              },
            },
          },
        ],
      },
      output: {
        width: 256,
        height: 256,
        responses: [{ identifier: 'default', format: { type: 'image/png' } }],
      },
      evalscript: layerType === 'NDVI' ? evalscriptNDVI : evalscriptRGB,
    };

    try {
      const { data } = await firstValueFrom(
        this.httpService.post<ArrayBuffer>(
          'https://sh.dataspace.copernicus.eu/api/v1/process',
          payload,
          {
            headers: {
              'Content-Type': 'application/json',
              Accept: 'image/png',
              Authorization: `Bearer ${token}`,
            },
            responseType: 'arraybuffer',
          },
        ),
      );

      return data;
    } catch (error: unknown) {
      const errMsg = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(
        'Failed to fetch tile from Copernicus Process API',
        errMsg,
      );
      throw new HttpException(
        'Failed to generate map tile',
        HttpStatus.BAD_GATEWAY,
      );
    }
  }

  /**
   * Fetch daily NDVI statistics for a given GeoJSON polygon over a date range
   */
  async getNdviStatistics(
    geojson: GeoJsonGeometry | string,
    startDate: string,
    endDate: string,
  ): Promise<NdviStatRecord[]> {
    const token = await this.getAuthToken();
    this.logger.debug(
      `Fetching NDVI statistics from Copernicus from ${startDate} to ${endDate}...`,
    );

    const geometry =
      typeof geojson === 'string'
        ? (JSON.parse(geojson) as GeoJsonGeometry)
        : geojson;

    const evalscriptNDVI = `
//VERSION=3
function setup() {
  return {
    input: ["B04", "B08", "CLP", "dataMask"],
    output: [
      { id: "default", bands: 1 },
      { id: "cloud", bands: 1 },
      { id: "dataMask", bands: 1 }
    ]
  };
}
function evaluatePixel(sample) {
  let ndvi = (sample.B08 - sample.B04) / (sample.B08 + sample.B04);
  return {
    default: [ndvi],
    cloud: [sample.CLP],
    dataMask: [sample.dataMask]
  };
}`;

    const payload = {
      input: {
        bounds: {
          geometry,
          properties: { crs: 'http://www.opengis.net/def/crs/EPSG/0/4326' },
        },
        data: [
          {
            type: 'sentinel-2-l2a',
            dataFilter: {
              timeRange: {
                from: `${startDate}T00:00:00Z`,
                to: `${endDate}T23:59:59Z`,
              },
            },
          },
        ],
      },
      aggregation: {
        timeRange: {
          from: `${startDate}T00:00:00Z`,
          to: `${endDate}T23:59:59Z`,
        },
        aggregationInterval: {
          of: 'P1D',
        },
        evalscript: evalscriptNDVI,
        resolutions: {
          default: [10, 10], // Sentinel-2 data is at 10m resolution
        },
      },
    };

    try {
      const { data } = await firstValueFrom(
        this.httpService.post<StatisticalResponse>(
          'https://sh.dataspace.copernicus.eu/api/v1/statistics',
          payload,
          {
            headers: {
              'Content-Type': 'application/json',
              Accept: 'application/json',
              Authorization: `Bearer ${token}`,
            },
          },
        ),
      );

      const stats: NdviStatRecord[] = [];

      if (data?.data) {
        for (const interval of data.data) {
          const bandStats = interval.outputs?.default?.bands?.B0?.stats;
          const cloudStats = interval.outputs?.cloud?.bands?.B0?.stats;
          const dateFrom = interval.interval?.from;

          if (bandStats && dateFrom && bandStats.sampleCount > 0) {
            stats.push({
              date: dateFrom,
              mean: bandStats.mean,
              max: bandStats.max,
              min: bandStats.min,
              cloudCover: cloudStats ? cloudStats.mean : 0.0,
            });
          }
        }
      }

      return stats;
    } catch (error: unknown) {
      const errMsg = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(
        'Failed to fetch NDVI statistics from Copernicus',
        errMsg,
      );
      throw new HttpException(
        'Failed to fetch NDVI historical data',
        HttpStatus.BAD_GATEWAY,
      );
    }
  }
}
