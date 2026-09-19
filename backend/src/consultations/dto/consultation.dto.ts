import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsArray, IsMongoId, IsNotEmpty, IsOptional, IsString, ValidateNested } from 'class-validator';

export class PrescriptionItemDto {
  @ApiProperty({ example: 'Doliprane', description: 'Nom du médicament' })
  @IsString()
  @IsNotEmpty()
  medicine: string;

  @ApiPropertyOptional({ example: '1000 mg', description: 'Dosage' })
  @IsOptional()
  @IsString()
  dosage?: string;

  @ApiPropertyOptional({ example: '1 comprimé', description: 'Posologie unitaire' })
  @IsOptional()
  @IsString()
  posology?: string;

  @ApiPropertyOptional({ example: '3 fois/jour', description: 'Fréquence de prise' })
  @IsOptional()
  @IsString()
  frequency?: string;

  @ApiPropertyOptional({ example: '5 jours', description: 'Durée du traitement' })
  @IsOptional()
  @IsString()
  duration?: string;

  @ApiPropertyOptional({ example: 'Après les repas', description: 'Instructions particulières' })
  @IsOptional()
  @IsString()
  instructions?: string;
}

export class ConsultationAttachmentDto {
  @ApiProperty({ example: 'ordonnance_00451.pdf', description: 'Nom du fichier' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: 'https://...', description: 'URL ou base64 du document' })
  @IsString()
  @IsNotEmpty()
  url: string;

  @ApiPropertyOptional({ example: 'application/pdf', description: 'Type MIME ou extension' })
  @IsOptional()
  @IsString()
  fileType?: string;
}

export class CreateConsultationDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID du patient' })
  @IsMongoId()
  @IsNotEmpty()
  patientId: string;

  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a13', description: 'ID du médecin' })
  @IsMongoId()
  @IsNotEmpty()
  doctorId: string;

  @ApiProperty({ example: '2026-09-09', description: 'Date de la consultation (YYYY-MM-DD)' })
  @IsString()
  @IsNotEmpty()
  date: string;

  @ApiProperty({ example: 'Douleurs thoraciques récurrentes', description: 'Motif de consultation' })
  @IsString()
  @IsNotEmpty()
  motive: string;

  @ApiPropertyOptional({ example: 'Douleur irradiante, essoufflement à l\'effort' })
  @IsOptional()
  @IsString()
  symptoms?: string;

  @ApiPropertyOptional({ example: 'Auscultation cardiaque, palpation abdominale' })
  @IsOptional()
  @IsString()
  clinicalExam?: string;

  @ApiProperty({ example: 'Angine de poitrine stable', description: 'Diagnostic posé' })
  @IsString()
  @IsNotEmpty()
  diagnostic: string;

  @ApiPropertyOptional({ example: 'Aspirine 100mg — 1 comprimé/jour\nBêtabloquant — selon dosage' })
  @IsOptional()
  @IsString()
  prescription?: string;

  @ApiPropertyOptional({ type: [PrescriptionItemDto], description: 'Ordonnance structurée (médicaments)' })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PrescriptionItemDto)
  prescriptionItems?: PrescriptionItemDto[];

  @ApiPropertyOptional({ type: [ConsultationAttachmentDto], description: 'Documents joints (ordonnance PDF/image)' })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ConsultationAttachmentDto)
  attachments?: ConsultationAttachmentDto[];

  @ApiPropertyOptional({ example: 'Patient anxieux, bonne compliance médicamenteuse' })
  @IsOptional()
  @IsString()
  observations?: string;

  @ApiPropertyOptional({ example: '2026-10-09', description: 'Date de suivi planifiée (YYYY-MM-DD)' })
  @IsOptional()
  @IsString()
  followUpDate?: string;

  @ApiPropertyOptional({ example: 'ECG de contrôle prévu' })
  @IsOptional()
  @IsString()
  followUpNotes?: string;
}

export class UpdateConsultationDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  motive?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  symptoms?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  clinicalExam?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  diagnostic?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  prescription?: string;

  @ApiPropertyOptional({ type: [PrescriptionItemDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PrescriptionItemDto)
  prescriptionItems?: PrescriptionItemDto[];

  @ApiPropertyOptional({ type: [ConsultationAttachmentDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ConsultationAttachmentDto)
  attachments?: ConsultationAttachmentDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observations?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  followUpDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  followUpNotes?: string;
}
