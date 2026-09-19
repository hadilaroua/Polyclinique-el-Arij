import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';
import { Role } from '../../common/enums/role.enum';

/**
 * DTO pour la création d'un compte staff par l'Admin.
 * L'Admin crée le compte directement avec un mot de passe temporaire.
 * Le staff se connecte et change son mot de passe lors de la première connexion.
 */
export class CreateStaffAccountDto {
  @ApiProperty({ example: 'Ahmed', description: 'Prénom du membre du personnel' })
  @IsString()
  @IsNotEmpty()
  firstName: string;

  @ApiProperty({ example: 'Ben Salem', description: 'Nom de famille' })
  @IsString()
  @IsNotEmpty()
  lastName: string;

  @ApiProperty({ example: 'a.bensalem@polyclinique-arij.tn', description: 'Email professionnel unique' })
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @ApiProperty({
    example: 'TempPass123!',
    description: 'Mot de passe temporaire — le staff devra le changer à la première connexion',
    minLength: 6,
  })
  @IsString()
  @MinLength(6)
  password: string;

  @ApiPropertyOptional({ example: '+216 98 765 432' })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional({ example: '12345678', description: 'Numéro CIN' })
  @IsOptional()
  @IsString()
  cin?: string;

  @ApiProperty({
    enum: [Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN, Role.ADMIN],
    example: Role.DOCTOR,
    description: 'Rôle du membre du personnel',
  })
  @IsEnum(Role)
  @IsNotEmpty()
  role: Role;

  // --- Champs spécifiques selon le rôle ---

  @ApiPropertyOptional({ example: 'Cardiologie', description: 'Spécialité (DOCTOR uniquement)' })
  @IsOptional()
  @IsString()
  specialty?: string;

  @ApiPropertyOptional({ example: 'TN-MED-4421', description: 'Numéro d\'ordre médical (DOCTOR uniquement)' })
  @IsOptional()
  @IsString()
  licenseNumber?: string;

  @ApiPropertyOptional({ example: 'Urgences', description: 'Service d\'affectation' })
  @IsOptional()
  @IsString()
  service?: string;

  @ApiPropertyOptional({ example: 'Matin (07h-15h)', description: 'Shift (NURSE, MIDWIFE, TECHNICIAN)' })
  @IsOptional()
  @IsString()
  shift?: string;

  @ApiPropertyOptional({ example: 'Radiologie', description: 'Département technique (TECHNICIAN uniquement)' })
  @IsOptional()
  @IsString()
  technicalDepartment?: string;

  @ApiPropertyOptional({ example: 'Scanner', description: 'Spécialité technique (TECHNICIAN uniquement)' })
  @IsOptional()
  @IsString()
  technicalSpecialty?: string;

  @ApiPropertyOptional({ example: 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?w=200' })
  @IsOptional()
  @IsString()
  avatarUrl?: string;
}
