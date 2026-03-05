import { Controller, Get, Param, Post, Body, Res } from '@nestjs/common';
import { MapTilesService } from './map-tiles.service';
import { CreateMapTileDto } from './dto/create-map-tile.dto';
import type { Response } from 'express';

@Controller('map-tiles')
export class MapTilesController {
  constructor(private readonly mapTilesService: MapTilesService) {}

  @Get(':plotId/dates')
  getAvailableDates(@Param('plotId') plotId: string) {
    return this.mapTilesService.getAvailableDates(plotId);
  }

  @Get(':plotId/:date/layers')
  getLayersForDate(
    @Param('plotId') plotId: string,
    @Param('date') date: string,
  ) {
    return this.mapTilesService.getLayersForDate(plotId, date);
  }

  // Proxy XYZ tiles directly to Copernicus Process API
  @Get('proxy/:plotId/:date/:layerType/:z/:x/:y.png')
  async getProxyTile(
    @Param('plotId') plotId: string,
    @Param('date') date: string,
    @Param('layerType') layerType: 'RGB' | 'NDVI',
    @Param('z') z: string,
    @Param('x') x: string,
    @Param('y') y: string,
    @Res() res: Response,
  ): Promise<void> {
    const imageBuffer: ArrayBuffer = await this.mapTilesService.getProxyTile(
      plotId,
      date,
      layerType,
      parseInt(z, 10),
      parseInt(x, 10),
      parseInt(y, 10),
    );

    res.set({
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=86400', // Cache for 1 day
    });
    res.send(Buffer.from(imageBuffer));
  }

  @Post()
  createMapTileRecord(@Body() createMapTileDto: CreateMapTileDto) {
    return this.mapTilesService.createMapTileRecord(createMapTileDto);
  }
}
