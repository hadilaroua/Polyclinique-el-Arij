import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateIf,
} from 'class-validator';
import { Role } from '../../common/enums/role.enum';

export class CreateAuthorizedStaffDto {
  @ApiProperty({ example: '05050505', description: 'CIN autorise par l administration' })
  @IsString()
  @IsNotEmpty()
  cin: string;

  @ApiProperty({ example: 'Mehdi' })
  @IsString()
  @IsNotEmpty()
  firstName: string;

  @ApiProperty({ example: 'Ben Salem' })
  @IsString()
  @IsNotEmpty()
  lastName: string;

  @ApiProperty({ enum: [Role.DOCTOR, Role.NURSE, Role.ADMIN], example: Role.DOCTOR })
  @IsIn([Role.DOCTOR, Role.NURSE, Role.ADMIN])
  role: Role;

  @ApiPropertyOptional({ example: 'Chirurgie Generale', description: 'Obligatoire pour un medecin' })
  @IsOptional()
  @IsString()
  specialty?: string;

  @ApiPropertyOptional({ example: 'TN-MED-12121212', description: 'Obligatoire pour un médecin' })
  @ValidateIf((dto) => dto.role === Role.DOCTOR)
  @IsNotEmpty({ message: 'Le numéro d’ordre médical est obligatoire pour un médecin' })
  @IsOptional()
  @IsString()
  licenseNumber?: string;

  @ApiPropertyOptional({ example: 'Service Chirurgie', description: 'Obligatoire pour un infirmier' })
  @IsOptional()
  @IsString()
  department?: string;

}

export class UpdateAuthorizedStaffDto {
  @ApiPropertyOptional({ example: 'Mehdi' })
  @IsOptional()
  @IsString()
  firstName?: string;

  @ApiPropertyOptional({ example: 'Ben Salem' })
  @IsOptional()
  @IsString()
  lastName?: string;

  @ApiPropertyOptional({ example: 'Cardiologie' })
  @IsOptional()
  @IsString()
  specialty?: string;

  @ApiPropertyOptional({ example: 'TN-MED-12121212' })
  @IsOptional()
  @IsString()
  licenseNumber?: string;

  @ApiPropertyOptional({ example: 'Service Urgences' })
  @IsOptional()
  @IsString()
  department?: string;
}

export class CreateAuthorizedPatientDto {
  @ApiProperty({ example: '15151515', description: 'CIN autorisé par l’administration' })
  @IsString()
  @IsNotEmpty()
  cin: string;

  @ApiProperty({ example: 'Ahmed' })
  @IsString()
  @IsNotEmpty()
  firstName: string;

  @ApiProperty({ example: 'Ben Salah' })
  @IsString()
  @IsNotEmpty()
  lastName: string;

  @ApiProperty({ example: 'ahmed.bensalah@arij.tn' })
  @IsEmail({}, { message: 'Adresse email invalide' })
  email: string;
}
