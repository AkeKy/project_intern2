import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { PlotsService } from './plots.service';
import { CreatePlotDto } from './dto/create-plot.dto';

@Controller('plots')
export class PlotsController {
  constructor(private readonly plotsService: PlotsService) {}

  @Post()
  async create(@Body() createPlotDto: CreatePlotDto) {
    console.log('Received create plot request:', createPlotDto);
    return this.plotsService.create(createPlotDto);
  }

  @Get()
  findAll() {
    return this.plotsService.findAll();
  }

  @Get('site/:siteId')
  findBySite(@Param('siteId') siteId: string) {
    return this.plotsService.findBySite(siteId);
  }

  @Get(':id/ndvi-history')
  getNdviHistory(@Param('id') id: string) {
    return this.plotsService.getNdviHistory(id);
  }
}
