import {
  IsString,
  IsNotEmpty,
  IsNumber,
  IsArray,
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
  @IsNotEmpty()
  siteId: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => Coordinate)
  coordinates: Coordinate[];
}
