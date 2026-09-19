import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsMongoId,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';

export class TreatmentItemDto {
  @ApiProperty({ example: 'Amoxicilline' })
  @IsString()
  @IsNotEmpty()
  medication: string;

  @ApiProperty({ example: '1g' })
  @IsString()
  @IsNotEmpty()
  dosage: string;

  @ApiPropertyOptional({ example: '2 fois par jour pendant 7 jours' })
  @IsOptional()
  @IsString()
  frequency?: string;

  @ApiPropertyOptional({ example: '2026-09-01' })
  @IsOptional()
  @IsString()
  startDate?: string;

  @ApiPropertyOptional({ example: '2026-09-08' })
  @IsOptional()
  @IsString()
  endDate?: string;

  @ApiPropertyOptional({ example: 'Dr. Ben Salem' })
  @IsOptional()
  @IsString()
  prescribingDoctor?: string;
}

export class ConsultationEntryDto {
  @ApiPropertyOptional({ example: '2026-09-05T10:00:00.000Z' })
  @IsOptional()
  @IsString()
  date?: string;

  @ApiProperty({ example: 'Dr. Karima Trabelsi' })
  @IsString()
  @IsNotEmpty()
  doctorName: string;

  @ApiPropertyOptional({ example: 'Cardiologie' })
  @IsOptional()
  @IsString()
  doctorSpecialty?: string;

  @ApiProperty({ example: 'Douleurs thoraciques d’effort' })
  @IsString()
  @IsNotEmpty()
  motive: string;

  @ApiProperty({ example: 'Hypertension artérielle modérée' })
  @IsString()
  @IsNotEmpty()
  diagnostic: string;

  @ApiPropertyOptional({ example: 'Amlodipine 5mg 1cp le matin' })
  @IsOptional()
  @IsString()
  prescription?: string;

  @ApiPropertyOptional({ example: 'Contrôle tensionnel dans 15 jours' })
  @IsOptional()
  @IsString()
  observations?: string;
}

export class CreateMedicalRecordDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12' })
  @IsMongoId()
  @IsNotEmpty()
  patientId: string;

  @ApiPropertyOptional({ example: ['Pénicilline', 'Iode'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  allergies?: string[];

  @ApiPropertyOptional({
    example: {
      personal: ['Asthme'],
      family: ['Diabète Type 2'],
      surgical: ['Appendicectomie en 2018'],
    },
  })
  @IsOptional()
  antecedents?: {
    personal: string[];
    family: string[];
    surgical: string[];
  };

  @ApiPropertyOptional({ type: [TreatmentItemDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TreatmentItemDto)
  treatments?: TreatmentItemDto[];

  @ApiPropertyOptional({ example: 'Patient suivi au service ambulatoire' })
  @IsOptional()
  @IsString()
  generalNotes?: string;
}

export class UpdateMedicalRecordDto {
  @ApiPropertyOptional({ example: ['Pénicilline', 'Iode'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  allergies?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  antecedents?: {
    personal: string[];
    family: string[];
    surgical: string[];
  };

  @ApiPropertyOptional({ type: [TreatmentItemDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TreatmentItemDto)
  treatments?: TreatmentItemDto[];

  @ApiPropertyOptional({ example: 'Notes de suivi' })
  @IsOptional()
  @IsString()
  generalNotes?: string;
}
