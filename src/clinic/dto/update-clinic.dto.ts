import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsNumber,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';

export class ClinicDepartmentDto {
  @ApiPropertyOptional({ example: 'Cardiologie' })
  @IsString()
  name: string;

  @ApiPropertyOptional({ example: 'Prise en charge des urgences et pathologies cardiovasculaires' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: 'Dr. Karima Trabelsi' })
  @IsOptional()
  @IsString()
  headDoctor?: string;

  @ApiPropertyOptional({ example: 'favorite' })
  @IsOptional()
  @IsString()
  icon?: string;
}

export class UpdateClinicInfoDto {
  @ApiPropertyOptional({ example: 'Polyclinique Arij Djerba' })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional({ example: 'Excellence médicale et assistance continue' })
  @IsOptional()
  @IsString()
  slogan?: string;

  @ApiPropertyOptional({ example: 'Midoun, Djerba 4116' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ example: '+216 75 730 000' })
  @IsOptional()
  @IsString()
  phonePrimary?: string;

  @ApiPropertyOptional({ example: '+216 75 730 112' })
  @IsOptional()
  @IsString()
  emergencyPhone?: string;

  @ApiPropertyOptional({ example: 'contact@polyclinique-arij.tn' })
  @IsOptional()
  @IsString()
  email?: string;

  @ApiPropertyOptional({ example: 'https://polyclinique-arij.tn' })
  @IsOptional()
  @IsString()
  website?: string;

  @ApiPropertyOptional({ example: 'Urgences 24h/24 et 7j/7' })
  @IsOptional()
  @IsString()
  openingHours?: string;

  @ApiPropertyOptional({ example: 33.8075 })
  @IsOptional()
  @IsNumber()
  latitude?: number;

  @ApiPropertyOptional({ example: 10.9922 })
  @IsOptional()
  @IsNumber()
  longitude?: number;

  @ApiPropertyOptional({ type: [ClinicDepartmentDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ClinicDepartmentDto)
  departments?: ClinicDepartmentDto[];

  @ApiPropertyOptional({
    example: ['Urgences 24/7', 'Imagerie Médicale (Scanner, Échographie)', 'Laboratoire d’analyses', 'Chirurgie ambulatoire'],
  })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  services?: string[];

  @ApiPropertyOptional({
    example: ['Parking gratuit disponible', 'Accès PMR', 'Prise en charge CNAM et conventions assurances'],
  })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  practicalInfo?: string[];
}
