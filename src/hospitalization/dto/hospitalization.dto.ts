import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsMongoId,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
} from 'class-validator';
import { BedStatus } from '../schemas/bed.schema';
import { StayStatus } from '../schemas/hospital-stay.schema';

// --- Room DTOs ---
export class CreateRoomDto {
  @ApiProperty({ example: '101', description: 'Numéro de chambre' })
  @IsString()
  @IsNotEmpty()
  number: string;

  @ApiProperty({ example: 'Maternité' })
  @IsString()
  @IsNotEmpty()
  service: string;

  @ApiPropertyOptional({ example: 2, description: 'Capacité (nombre de lits)' })
  @IsOptional()
  @IsNumber()
  @IsPositive()
  capacity?: number;

  @ApiPropertyOptional({ example: '1er étage' })
  @IsOptional()
  floor?: any;

  @ApiPropertyOptional({ example: 'STANDARD' })
  @IsOptional()
  @IsString()
  roomType?: string;

  @ApiPropertyOptional({ example: 'Chambre double avec salle de bain' })
  @IsOptional()
  @IsString()
  description?: string;
}

export class UpdateRoomDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  number?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  service?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  capacity?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  floor?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

// --- Bed DTOs ---
export class CreateBedDto {
  @ApiProperty({ example: 'A', description: 'Numéro ou lettre du lit (ex: A, B, 1, 2)' })
  @IsString()
  @IsNotEmpty()
  number: string;

  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID de la chambre' })
  @IsMongoId()
  @IsNotEmpty()
  roomId: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}

export class UpdateBedDto {
  @ApiPropertyOptional({ enum: BedStatus })
  @IsOptional()
  @IsEnum(BedStatus)
  status?: BedStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}

// --- HospitalStay DTOs ---
export class CreateHospitalStayDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID du patient' })
  @IsMongoId()
  @IsNotEmpty()
  patientId: string;

  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a13', description: 'ID du lit' })
  @IsMongoId()
  @IsNotEmpty()
  bedId: string;

  @ApiProperty({ example: 'Maternité' })
  @IsString()
  @IsNotEmpty()
  service: string;

  @ApiPropertyOptional({ example: '60c72b2f9b1d8b2bad8e9a14' })
  @IsOptional()
  @IsMongoId()
  admittedByDoctorId?: string;

  @ApiProperty({ example: '2026-09-09T08:00:00Z' })
  @IsDateString()
  admissionDate: string;

  @ApiPropertyOptional({ example: 'Accouchement programmé par césarienne' })
  @IsOptional()
  @IsString()
  admissionReason?: string;
}

export class DischargePatientDto {
  @ApiProperty({ example: '2026-09-12T10:00:00Z' })
  @IsDateString()
  dischargeDate: string;

  @ApiPropertyOptional({ example: 'Sortie après accouchement normal — mère et enfant en bonne santé' })
  @IsOptional()
  @IsString()
  dischargeNotes?: string;
}
