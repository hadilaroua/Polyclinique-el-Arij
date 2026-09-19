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
 * DTO d'auto-inscription pour le personnel de la clinique (Médecins, Infirmiers, Sages-femmes, Techniciens).
 * L'inscription ne réussit QUE SI le CIN a été préalablement accrédité par l'Administrateur dans le registre interne.
 */
export class RegisterStaffDto {
  @ApiProperty({
    example: '05050505',
    description: 'Numéro de CIN accrédité préalablement par la Direction de la clinique',
  })
  @IsString()
  @IsNotEmpty({ message: 'Le numéro CIN est obligatoire pour valider votre statut' })
  cin: string;

  @ApiProperty({ example: 'dr.mehdi@arij.tn' })
  @IsEmail({}, { message: 'Adresse email valide requise' })
  email: string;

  @ApiProperty({ example: 'DoctorPass123!' })
  @IsString()
  @MinLength(6, { message: 'Le mot de passe doit comporter au moins 6 caractères' })
  password: string;

  @ApiPropertyOptional({ example: 'Mehdi', description: 'Prénom (optionnel, complété via le registre Admin si omis)' })
  @IsOptional()
  @IsString()
  firstName?: string;

  @ApiPropertyOptional({ example: 'Ben Salem', description: 'Nom (optionnel, complété via le registre Admin si omis)' })
  @IsOptional()
  @IsString()
  lastName?: string;

  @ApiPropertyOptional({ example: '+216 98 555 666' })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional({
    enum: [Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN],
    example: Role.DOCTOR,
    description: 'Rôle souhaité (vérifié rigoureusement contre le rôle pré-attribué par l\'Admin)',
  })
  @IsOptional()
  @IsEnum(Role, { message: 'Rôle professionnel invalide' })
  role?: Role;

  @ApiPropertyOptional({ example: 'Cardiologie' })
  @IsOptional()
  @IsString()
  specialty?: string;

  @ApiPropertyOptional({ example: 'TN-MED-12345' })
  @IsOptional()
  @IsString()
  licenseNumber?: string;

  @ApiPropertyOptional({ example: 'Consultations Externes' })
  @IsOptional()
  @IsString()
  service?: string;

  @ApiPropertyOptional({ example: 'Urgences' })
  @IsOptional()
  @IsString()
  department?: string;

  @ApiPropertyOptional({ example: 'Matin (07h-15h)' })
  @IsOptional()
  @IsString()
  shift?: string;

  @ApiPropertyOptional({ example: 'Radiologie' })
  @IsOptional()
  @IsString()
  technicalDepartment?: string;

  @ApiPropertyOptional({ example: 'Scanner' })
  @IsOptional()
  @IsString()
  technicalSpecialty?: string;

  @ApiPropertyOptional({ example: 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?w=200' })
  @IsOptional()
  @IsString()
  avatarUrl?: string;
}
