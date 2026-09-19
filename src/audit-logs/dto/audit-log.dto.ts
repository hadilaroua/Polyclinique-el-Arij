import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsMongoId, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { Role } from '../../common/enums/role.enum';

export class CreateAuditLogDto {
  @ApiProperty({ example: 'CREATION_CONSULTATION', description: 'Action réalisée' })
  @IsString()
  @IsNotEmpty()
  action: string;

  @ApiPropertyOptional({ example: 'CONSULTATION', description: 'Catégorie de l\'acte' })
  @IsOptional()
  @IsString()
  category?: string;

  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a13', description: 'ID de l\'utilisateur acteur' })
  @IsMongoId()
  @IsNotEmpty()
  actorId: string;

  @ApiProperty({ example: 'Dr. Rachid Aroua', description: 'Nom complet du professionnel' })
  @IsString()
  @IsNotEmpty()
  actorName: string;

  @ApiProperty({ enum: Role, example: Role.DOCTOR, description: 'Rôle du professionnel' })
  @IsEnum(Role)
  @IsNotEmpty()
  actorRole: Role;

  @ApiPropertyOptional({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID du patient' })
  @IsOptional()
  @IsMongoId()
  patientId?: string;

  @ApiPropertyOptional({ example: 'Ahmed Ben Ali', description: 'Nom du patient' })
  @IsOptional()
  @IsString()
  patientName?: string;

  @ApiPropertyOptional({ example: 'PAT-2026-00125', description: 'Numéro de dossier patient' })
  @IsOptional()
  @IsString()
  patientDossier?: string;

  @ApiPropertyOptional({ example: '60c72b2f9b1d8b2bad8e9a99', description: 'ID de l\'entité cible' })
  @IsOptional()
  @IsString()
  entityId?: string;

  @ApiPropertyOptional({ example: 'Consultation', description: 'Nom du modèle/table cible' })
  @IsOptional()
  @IsString()
  targetEntity?: string;

  @ApiPropertyOptional({ example: 'Consultation cardiologique réalisée, diagnostic posé : Angine de poitrine' })
  @IsOptional()
  @IsString()
  details?: string;

  @ApiPropertyOptional()
  @IsOptional()
  metadata?: Record<string, any>;
}
