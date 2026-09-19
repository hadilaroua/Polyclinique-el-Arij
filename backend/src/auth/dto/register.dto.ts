import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { EmergencyContactDto } from '../../patients/dto/create-patient.dto';

export class RegisterDto {
  @ApiProperty({ example: '15151515', description: 'CIN préalablement autorisé par l’administration' })
  @IsString()
  @IsNotEmpty({ message: 'Le numéro de carte d’identité est obligatoire' })
  cin: string;

  @ApiProperty({ example: 'Hadil' })
  @IsString()
  @IsNotEmpty({ message: 'Le prénom est obligatoire' })
  firstName: string;

  @ApiProperty({ example: 'Guermazi' })
  @IsString()
  @IsNotEmpty({ message: 'Le nom est obligatoire' })
  lastName: string;

  @ApiProperty({ example: 'hadil.guermazi@example.com' })
  @IsEmail({}, { message: 'Adresse email invalide' })
  email: string;

  @ApiProperty({ example: 'Securite2026!' })
  @IsString()
  @MinLength(6, {
    message: 'Le mot de passe doit comporter au moins 6 caractères',
  })
  password: string;

  @ApiPropertyOptional({ example: '+216 20 123 456' })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiProperty({ example: '2001-04-12' })
  @IsString()
  @IsNotEmpty({ message: 'La date de naissance est obligatoire' })
  dateOfBirth: string;

  @ApiPropertyOptional({ example: 'F' })
  @IsOptional()
  @IsString()
  gender?: string;

  @ApiPropertyOptional({ example: 'A+' })
  @IsOptional()
  @IsString()
  bloodType?: string;

  @ApiPropertyOptional({ type: EmergencyContactDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => EmergencyContactDto)
  emergencyContact?: EmergencyContactDto;
}
