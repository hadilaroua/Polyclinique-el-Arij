import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsEnum,
  IsMongoId,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';
import { AlertLevel } from '../../common/enums/alert-level.enum';
import { Role } from '../../common/enums/role.enum';

export class CreateAlertDto {
  @ApiPropertyOptional({ example: '60c72b2f9b1d8b2bad8e9a12' })
  @IsOptional()
  @IsMongoId()
  patientId?: string;

  @ApiProperty({ enum: AlertLevel, example: AlertLevel.WARNING })
  @IsEnum(AlertLevel)
  level: AlertLevel;

  @ApiProperty({ example: 'Risque d’interaction médicamenteuse' })
  @IsString()
  @IsNotEmpty({ message: 'Le titre de l’alerte est obligatoire' })
  title: string;

  @ApiProperty({
    example:
      'Le patient présente une allergie sévère à la pénicilline signalée lors de l’admission.',
  })
  @IsString()
  @IsNotEmpty({ message: 'La description de l’alerte est obligatoire' })
  description: string;

  @ApiPropertyOptional({ example: 'Allergie' })
  @IsOptional()
  @IsString()
  category?: string;

  @ApiPropertyOptional({
    enum: Role,
    isArray: true,
    example: [Role.DOCTOR, Role.NURSE],
  })
  @IsOptional()
  @IsArray()
  targetRoles?: Role[];

  @ApiPropertyOptional({
    example: '60c72b2f9b1d8b2bad8e9a15',
    description: 'ID du médecin destinataire spécifique',
  })
  @IsOptional()
  @IsMongoId()
  targetDoctorId?: string;
}
