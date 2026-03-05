import { IsDateString, IsString, IsNotEmpty } from 'class-validator';
import { CalculateCarbonDto } from './calculate-carbon.dto';

export class SaveCarbonDto extends CalculateCarbonDto {
  @IsString()
  @IsNotEmpty()
  plotId: string;

  @IsDateString()
  @IsNotEmpty()
  declare startDate: string;

  @IsDateString()
  @IsNotEmpty()
  declare harvestDate: string;
}
