import { Controller, Post, Get, Body, Param } from '@nestjs/common';
import { CarbonService } from './carbon.service';
import { CalculateCarbonDto } from './dto/calculate-carbon.dto';
import { SaveCarbonDto } from './dto/save-carbon.dto';

@Controller('carbon')
export class CarbonController {
  constructor(private readonly carbonService: CarbonService) {}

  @Post('calculate')
  calculate(@Body() dto: CalculateCarbonDto) {
    return this.carbonService.calculateCarbonCredit(
      dto.areaRai,
      dto.isAWD,
      dto.fertilizerN_kg_ha ?? 0,
      dto.startDate,
      dto.harvestDate,
    );
  }

  @Post('save')
  async save(@Body() dto: SaveCarbonDto) {
    console.log('Received save request:', dto);
    return this.carbonService.saveCalculation(dto);
  }

  @Get('summary/:siteId')
  getSummary(@Param('siteId') siteId: string) {
    return this.carbonService.getSiteSummary(siteId);
  }
}
