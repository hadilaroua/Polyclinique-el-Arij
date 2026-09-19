import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsMongoId,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';

export class EmergencyContactDto {
  @ApiPropertyOptional({ example: 'Samir Ben Ali' })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional({ example: '+216 98 765 432' })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional({ example: 'Frère' })
  @IsOptional()
  @IsString()
  relation?: string;
}

/**
 * DTO de création d'un patient (V1 — entité métier sans compte utilisateur)
 * Géré uniquement par l'administration.
 */
export class CreatePatientDto {
  @ApiProperty({ example: 'Ahmed' })
  @IsString()
  @IsNotEmpty({ message: 'Le prénom est obligatoire' })
  firstName: string;

  @ApiProperty({ example: 'Ben Salah' })
  @IsString()
  @IsNotEmpty({ message: 'Le nom de famille est obligatoire' })
  lastName: string;

  @ApiProperty({ example: '12345678', description: 'Numéro CIN unique' })
  @IsString()
  @IsNotEmpty({ message: 'Le numéro CIN est obligatoire' })
  cin: string;

  @ApiProperty({ example: '1985-06-15', description: 'Format YYYY-MM-DD' })
  @IsString()
  @IsNotEmpty({ message: 'La date de naissance est obligatoire' })
  dateOfBirth: string;

  @ApiPropertyOptional({ example: 'Homme', enum: ['Homme', 'Femme', 'Autre', 'Non spécifié'] })
  @IsOptional()
  @IsString()
  gender?: string;

  @ApiPropertyOptional({ example: '+216 20 123 456' })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional({ example: 'Midoun, Djerba' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ example: 'O+', enum: ['A+','A-','B+','B-','AB+','AB-','O+','O-','Inconnu'] })
  @IsOptional()
  @IsString()
  bloodType?: string;

  @ApiPropertyOptional({ type: EmergencyContactDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => EmergencyContactDto)
  emergencyContact?: EmergencyContactDto;

  @ApiPropertyOptional({ example: ['Pénicilline', 'Pollen'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  allergies?: string[];

  @ApiPropertyOptional({ example: ['Hypertension', 'Diabète'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  chronicDiseases?: string[];

  /**
   * userId — RÉSERVÉ V2. Ne pas utiliser en V1.
   * Sera rempli automatiquement lors de la création du compte patient (V2).
   */
  @ApiPropertyOptional({ description: 'Réservé V2 — ID compte utilisateur futur' })
  @IsOptional()
  @IsMongoId()
  userId?: string;
}
