import {
  IsString,
  IsNotEmpty,
  IsNumber,
  IsArray,
  IsOptional,
  ValidateNested,
  IsEnum,
} from 'class-validator';
import { Type } from 'class-transformer';

export enum PlotType {
  IRRIGATED = 'irrigated',
  RAINFED = 'rainfed',
  OTHER = 'other',
}

export class Coordinate {
  @IsNumber()
  lat: number;

  @IsNumber()
  lng: number;
}

export class CreatePlotDto {
  @IsString()
  @IsNotEmpty()
  farmId: string;

  @IsString()
  @IsNotEmpty()
  plotName: string;

  @IsEnum(PlotType)
  @IsNotEmpty()
  plotType: PlotType;

  @IsString()
  @IsOptional()
  siteId?: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => Coordinate)
  coordinates: Coordinate[];
}
