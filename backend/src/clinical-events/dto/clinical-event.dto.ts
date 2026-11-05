import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export enum ProcedureTypeEnum {
  SURGERY = 'SURGERY',
  CESAREAN = 'CESAREAN',
  DELIVERY = 'DELIVERY',
  PROCEDURE = 'PROCEDURE',
  OTHER = 'OTHER',
}

export enum EventStatusEnum {
  SCHEDULED = 'SCHEDULED',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
}

export class CreateClinicalEventDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID du patient' })
  @IsNotEmpty()
  @IsString()
  patientId: string;

  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a13', description: 'ID du médecin praticien' })
  @IsNotEmpty()
  @IsString()
  doctorId: string;

  @ApiProperty({ example: 'Bloc opératoire 1', description: 'Salle ou Bloc réservé' })
  @IsNotEmpty()
  @IsString()
  roomId: string;

  @ApiProperty({ example: 'CESAREAN', enum: ProcedureTypeEnum })
  @IsNotEmpty()
  @IsString()
  procedureType: string;

  @ApiPropertyOptional({ example: 'Césarienne programmée' })
  @IsOptional()
  @IsString()
  procedureTitle?: string;

  @ApiProperty({ example: '2026-10-15', description: 'Date de l intervention (YYYY-MM-DD)' })
  @IsNotEmpty()
  @IsString()
  date: string;

  @ApiProperty({ example: '09:00', description: 'Heure de début (HH:mm)' })
  @IsNotEmpty()
  @IsString()
  startTime: string;

  @ApiProperty({ example: '10:30', description: 'Heure de fin (HH:mm)' })
  @IsNotEmpty()
  @IsString()
  endTime: string;

  @ApiPropertyOptional({ example: 'Préparation préopératoire à effectuer avant 08:30' })
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional({ example: ['60c72b2f9b1d8b2bad8e9a14'] })
  @IsOptional()
  @IsArray()
  assignedStaffIds?: string[];
}

export class UpdateClinicalEventDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  roomId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  procedureType?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  procedureTitle?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  date?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  startTime?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  endTime?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  status?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  assignedStaffIds?: string[];
}

export class CheckAvailabilityDto {
  @ApiProperty({ example: 'Bloc opératoire 1' })
  @IsNotEmpty()
  @IsString()
  roomId: string;

  @ApiProperty({ example: '2026-10-15' })
  @IsNotEmpty()
  @IsString()
  date: string;

  @ApiProperty({ example: '09:00' })
  @IsNotEmpty()
  @IsString()
  startTime: string;

  @ApiProperty({ example: '10:30' })
  @IsNotEmpty()
  @IsString()
  endTime: string;

  @ApiPropertyOptional({ example: '60c72b2f9b1d8b2bad8e9a99' })
  @IsOptional()
  @IsString()
  excludeEventId?: string;
}
