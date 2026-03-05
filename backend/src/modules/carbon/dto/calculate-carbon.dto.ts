import { IsBoolean, IsDateString, IsNumber, IsOptional } from 'class-validator';

export class CalculateCarbonDto {
  @IsNumber()
  areaRai: number;

  @IsBoolean()
  isAWD: boolean;

  @IsNumber()
  @IsOptional()
  fertilizerN_kg_ha?: number;

  @IsDateString()
  @IsOptional()
  startDate?: string;

  @IsDateString()
  @IsOptional()
  harvestDate?: string;
}
