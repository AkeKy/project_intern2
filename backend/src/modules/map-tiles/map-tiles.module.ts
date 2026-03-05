import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { MapTilesController } from './map-tiles.controller';
import { MapTilesService } from './map-tiles.service';
import { CopernicusService } from './copernicus.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule, HttpModule],
  controllers: [MapTilesController],
  providers: [MapTilesService, CopernicusService],
  exports: [CopernicusService],
})
export class MapTilesModule {}
