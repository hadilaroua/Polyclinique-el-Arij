import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsMongoId,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
} from 'class-validator';
import { AppointmentStatus } from '../../common/enums/appointment-status.enum';

export class CreateAppointmentDto {
  @ApiPropertyOptional({
    example: '60c72b2f9b1d8b2bad8e9a12',
    description: 'ID du patient (rempli automatiquement si connecté en tant que Patient)',
  })
  @IsOptional()
  @IsMongoId()
  patientId?: string;

  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a44' })
  @IsMongoId()
  @IsNotEmpty({ message: 'L’identifiant du médecin est obligatoire' })
  doctorId: string;

  @ApiProperty({ example: '2026-09-15' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'La date doit respecter le format AAAA-MM-JJ (YYYY-MM-DD)',
  })
  date: string;

  @ApiProperty({ example: '10:30' })
  @IsString()
  @IsNotEmpty({ message: 'Le créneau horaire est obligatoire' })
  timeSlot: string;

  @ApiProperty({ example: 'Consultation de suivi cardiologique' })
  @IsString()
  @IsNotEmpty({ message: 'Le motif de consultation est obligatoire' })
  reason: string;
}

export class UpdateAppointmentStatusDto {
  @ApiProperty({ enum: AppointmentStatus, example: AppointmentStatus.CONFIRMED })
  @IsEnum(AppointmentStatus)
  status: AppointmentStatus;

  @ApiPropertyOptional({ example: 'Notes médicales du médecin...' })
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional({ example: 'Médecin en intervention d’urgence' })
  @IsOptional()
  @IsString()
  cancellationReason?: string;
}
