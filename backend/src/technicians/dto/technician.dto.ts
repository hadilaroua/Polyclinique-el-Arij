import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsMongoId,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateTechnicianDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12' })
  @IsMongoId()
  @IsNotEmpty()
  userId: string;

  @ApiProperty({ example: 'Radiologie', description: 'Département technique (ex: Radiologie, Laboratoire, PMA)' })
  @IsString()
  @IsNotEmpty()
  technicalDepartment: string;

  @ApiPropertyOptional({ example: 'Scanner', description: 'Spécialité technique précise' })
  @IsOptional()
  @IsString()
  technicalSpecialty?: string;

  @ApiPropertyOptional({ example: 'Radiologie / Scanner' })
  @IsOptional()
  @IsString()
  service?: string;

  @ApiPropertyOptional({ example: 'Matin (07h-15h)' })
  @IsOptional()
  @IsString()
  shift?: string;

  @ApiPropertyOptional({ example: 'TECH-2026-001' })
  @IsOptional()
  @IsString()
  registryId?: string;
}

export class UpdateTechnicianDto {
  @ApiPropertyOptional({ example: 'Laboratoire' })
  @IsOptional()
  @IsString()
  technicalDepartment?: string;

  @ApiPropertyOptional({ example: 'Biologie' })
  @IsOptional()
  @IsString()
  technicalSpecialty?: string;

  @ApiPropertyOptional({ example: 'Laboratoire' })
  @IsOptional()
  @IsString()
  service?: string;

  @ApiPropertyOptional({ example: 'Après-midi (15h-23h)' })
  @IsOptional()
  @IsString()
  shift?: string;

  @ApiPropertyOptional({ example: 'TECH-2026-002' })
  @IsOptional()
  @IsString()
  registryId?: string;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
