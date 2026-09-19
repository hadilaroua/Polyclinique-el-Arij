import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsIn,
  IsMongoId,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';

export class ScheduleSlotDto {
  @ApiProperty({
    example: 'Lundi',
    enum: [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ],
  })
  @IsIn([
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ])
  dayOfWeek: string;

  @ApiProperty({ example: '08:00' })
  @IsString()
  @IsNotEmpty()
  startTime: string;

  @ApiProperty({ example: '14:00' })
  @IsString()
  @IsNotEmpty()
  endTime: string;

  @ApiPropertyOptional({ example: 15, default: 15 })
  @IsOptional()
  @IsNumber()
  maxPatients?: number;

  @ApiPropertyOptional({ example: true, default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class CreateDoctorDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12' })
  @IsMongoId()
  @IsNotEmpty()
  userId: string;

  @ApiProperty({ example: 'Cardiologie' })
  @IsString()
  @IsNotEmpty({ message: 'La spécialité est requise' })
  specialty: string;

  @ApiProperty({ example: 'TN-MED-4421' })
  @IsString()
  @IsNotEmpty({ message: 'Le numéro d’ordre médical est requis' })
  licenseNumber: string;

  @ApiProperty({ example: 'Service Cardiologie & Urgences' })
  @IsString()
  @IsNotEmpty({ message: 'Le service clinique est requis' })
  service: string;

  @ApiPropertyOptional({ example: 'Bureau 102 - 1er étage' })
  @IsOptional()
  @IsString()
  officeRoom?: string;

  @ApiPropertyOptional({
    example:
      'Spécialiste en cardiologie interventionnelle et rythmologie avec 12 ans d’expérience.',
  })
  @IsOptional()
  @IsString()
  biography?: string;

  @ApiPropertyOptional({ example: 60 })
  @IsOptional()
  @IsNumber()
  consultationFee?: number;

  @ApiPropertyOptional({ type: [ScheduleSlotDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ScheduleSlotDto)
  schedules?: ScheduleSlotDto[];
}

export class UpdateDoctorDto {
  @ApiPropertyOptional({ example: 'Cardiologie' })
  @IsOptional()
  @IsString()
  specialty?: string;

  @ApiPropertyOptional({ example: 'Service Cardiologie' })
  @IsOptional()
  @IsString()
  service?: string;

  @ApiPropertyOptional({ example: 'Bureau 102 - 1er étage' })
  @IsOptional()
  @IsString()
  officeRoom?: string;

  @ApiPropertyOptional({ example: 'Biographie mise à jour...' })
  @IsOptional()
  @IsString()
  biography?: string;

  @ApiPropertyOptional({ example: 60 })
  @IsOptional()
  @IsNumber()
  consultationFee?: number;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;

  @ApiPropertyOptional({ type: [ScheduleSlotDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ScheduleSlotDto)
  schedules?: ScheduleSlotDto[];
}

export class UpdateScheduleDto {
  @ApiProperty({ type: [ScheduleSlotDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ScheduleSlotDto)
  schedules: ScheduleSlotDto[];
}
