import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsMongoId,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateVitalSignDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID du patient' })
  @IsMongoId()
  @IsNotEmpty()
  patientId: string;

  @ApiPropertyOptional({ example: '60c72b2f9b1d8b2bad8e9a15', description: 'ID de l\'infirmier/sage-femme' })
  @IsOptional()
  @IsMongoId()
  recordedByUserId?: string;

  @ApiPropertyOptional({ example: '2026-09-09T10:30:00Z', description: 'Date et heure de la mesure' })
  @IsOptional()
  @IsDateString()
  recordedAt?: string;

  @ApiPropertyOptional({ example: 37.2, description: 'Température (°C)' })
  @IsOptional()
  @IsNumber()
  temperature?: number;

  @ApiPropertyOptional({ example: 72, description: 'Fréquence cardiaque (bpm)' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  heartRate?: number;

  @ApiPropertyOptional({ example: 120, description: 'TA systolique (mmHg)' })
  @IsOptional()
  @IsNumber()
  bloodPressureSystolic?: number;

  @ApiPropertyOptional({ example: 80, description: 'TA diastolique (mmHg)' })
  @IsOptional()
  @IsNumber()
  bloodPressureDiastolic?: number;

  @ApiPropertyOptional({ example: 98, description: 'SpO2 (%)' })
  @IsOptional()
  @IsNumber()
  oxygenSaturation?: number;

  @ApiPropertyOptional({ example: 16, description: 'Fréquence respiratoire (cycles/min)' })
  @IsOptional()
  @IsNumber()
  respiratoryRate?: number;

  @ApiPropertyOptional({ example: 72.5, description: 'Poids (kg)' })
  @IsOptional()
  @IsNumber()
  weight?: number;

  @ApiPropertyOptional({ example: 175, description: 'Taille (cm)' })
  @IsOptional()
  @IsNumber()
  height?: number;

  @ApiPropertyOptional({ example: 1.1, description: 'Glycémie (g/L)' })
  @IsOptional()
  @IsNumber()
  bloodGlucose?: number;

  @ApiPropertyOptional({ example: 'Patient agité, mesure répétée' })
  @IsOptional()
  @IsString()
  notes?: string;
}
