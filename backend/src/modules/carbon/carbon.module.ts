import { Module } from '@nestjs/common';
import { CarbonController } from './carbon.controller';
import { CarbonService } from './carbon.service';

@Module({
  controllers: [CarbonController],
  providers: [CarbonService],
})
export class CarbonModule {}
