import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';
import { SpecialtyType } from '../schemas/specialty.schema';

export class CreateSpecialtyDto {
  @ApiProperty({ example: 'Cardiologie', description: 'Nom unique de la spécialité' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ enum: SpecialtyType, example: SpecialtyType.MEDICAL })
  @IsEnum(SpecialtyType)
  type: SpecialtyType;

  @ApiPropertyOptional({ example: 'Spécialité médicale du cœur et des vaisseaux' })
  @IsOptional()
  @IsString()
  description?: string;
}

export class UpdateSpecialtyDto {
  @ApiPropertyOptional({ example: 'Cardiologie interventionnelle' })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional({ enum: SpecialtyType })
  @IsOptional()
  @IsEnum(SpecialtyType)
  type?: SpecialtyType;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
