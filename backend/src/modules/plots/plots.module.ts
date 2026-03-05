import { Module } from '@nestjs/common';
import { PlotsService } from './plots.service';
import { PlotsController } from './plots.controller';
import { MapTilesModule } from '../map-tiles/map-tiles.module';

@Module({
  imports: [MapTilesModule],
  controllers: [PlotsController],
  providers: [PlotsService],
})
export class PlotsModule {}
