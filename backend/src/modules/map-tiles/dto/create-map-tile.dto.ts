import {
  IsString,
  IsNotEmpty,
  IsEnum,
  IsNumber,
  Min,
  IsDateString,
  IsOptional,
} from 'class-validator';
import { LayerType } from '@prisma/client';

export class CreateMapTileDto {
  @IsString()
  @IsNotEmpty()
  farmId: string;

  @IsDateString()
  date: string;

  @IsEnum(LayerType)
  layerType: LayerType;

  @IsNumber()
  @Min(0)
  minZoom: number;

  @IsNumber()
  @Min(0)
  maxZoom: number;

  @IsString()
  @IsNotEmpty()
  baseUrl: string;

  @IsOptional()
  @IsNumber()
  cloudCover?: number;
}
