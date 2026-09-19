import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsMongoId,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';
import { ExamPriority, ExamStatus } from '../schemas/exam.schema';

export class CreateExamDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID du patient' })
  @IsMongoId()
  @IsNotEmpty()
  patientId: string;

  @ApiPropertyOptional({ example: '60c72b2f9b1d8b2bad8e9a13', description: 'ID du médecin prescripteur (optionnel)' })
  @IsOptional()
  @IsMongoId()
  requestingDoctorId?: string;

  @ApiPropertyOptional({ example: '60c72b2f9b1d8b2bad8e9a14', description: 'ID du technicien ciblé (optionnel)' })
  @IsOptional()
  @IsMongoId()
  assignedTechnicianId?: string;

  @ApiProperty({ example: 'Scanner thoracique sans injection', description: 'Type d\'examen demandé' })
  @IsString()
  @IsNotEmpty()
  examType: string;

  @ApiPropertyOptional({ example: 'Radiologie / Scanner' })
  @IsOptional()
  @IsString()
  service?: string;

  @ApiProperty({ enum: ExamPriority, example: ExamPriority.HIGH })
  @IsEnum(ExamPriority)
  priority: ExamPriority;

  @ApiPropertyOptional({ example: 'Suspicion de pneumonie lobaire droite. Antécédents : asthme.' })
  @IsOptional()
  @IsString()
  requestNotes?: string;
}

export class AssignExamDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a14', description: 'ID du technicien assigné' })
  @IsMongoId()
  @IsNotEmpty()
  technicianId: string;
}

export class CompleteExamDto {
  @ApiProperty({ example: 'Opacité lobaire droite compatible avec une pneumonie. Pas de pleurésie.' })
  @IsString()
  @IsNotEmpty()
  result: string;

  @ApiPropertyOptional({ example: 'Patient légèrement agité lors du scan. Repositionnement effectué.' })
  @IsOptional()
  @IsString()
  technicalNotes?: string;

  @ApiPropertyOptional({ example: 'https://...', description: 'URL ou document joint du résultat' })
  @IsOptional()
  @IsString()
  resultDocumentUrl?: string;
}

export class UpdateExamDto {
  @ApiPropertyOptional({ example: '60c72b2f9b1d8b2bad8e9a14' })
  @IsOptional()
  @IsMongoId()
  assignedTechnicianId?: string;

  @ApiPropertyOptional({ enum: ExamStatus })
  @IsOptional()
  @IsEnum(ExamStatus)
  status?: ExamStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  result?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  technicalNotes?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  resultDocumentUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cancellationReason?: string;
}
