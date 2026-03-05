import { PartialType } from '@nestjs/mapped-types';
import { CreatePlotDto } from './create-plot.dto';

export class UpdatePlotDto extends PartialType(CreatePlotDto) {}
