import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsMongoId,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateMidwifeDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID du compte utilisateur' })
  @IsMongoId()
  @IsNotEmpty()
  userId: string;

  @ApiPropertyOptional({ example: 'Maternité', default: 'Maternité' })
  @IsOptional()
  @IsString()
  service?: string;

  @ApiPropertyOptional({ example: 'Matin (07h-15h)' })
  @IsOptional()
  @IsString()
  shift?: string;

  @ApiPropertyOptional({ example: 'SF-2026-001' })
  @IsOptional()
  @IsString()
  registryId?: string;

  @ApiPropertyOptional({ example: 'Notes supplémentaires' })
  @IsOptional()
  @IsString()
  notes?: string;
}

export class UpdateMidwifeDto {
  @ApiPropertyOptional({ example: 'Maternité' })
  @IsOptional()
  @IsString()
  service?: string;

  @ApiPropertyOptional({ example: 'Nuit (23h-07h)' })
  @IsOptional()
  @IsString()
  shift?: string;

  @ApiPropertyOptional({ example: 'SF-2026-001' })
  @IsOptional()
  @IsString()
  registryId?: string;

  @ApiPropertyOptional({ example: 'Notes' })
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
