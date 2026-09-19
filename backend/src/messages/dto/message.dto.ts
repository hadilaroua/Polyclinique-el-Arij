import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsEnum,
  IsMongoId,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { MessageType } from '../schemas/message.schema';

export class MessageAttachmentDto {
  @ApiProperty({ example: 'https://...' })
  @IsString()
  @IsNotEmpty()
  url: string;

  @ApiProperty({ example: 'ordonnance_analyse.pdf' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({ example: 'application/pdf' })
  @IsOptional()
  @IsString()
  fileType?: string;

  @ApiPropertyOptional({ example: 1024500 })
  @IsOptional()
  @IsNumber()
  sizeBytes?: number;
}

export class SendMessageDto {
  @ApiPropertyOptional({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID de l\'employé destinataire (si chat 1-à-1)' })
  @IsOptional()
  @IsMongoId()
  recipientId?: string;

  @ApiPropertyOptional({ example: 'GARDE_URGENCES', description: 'ID du groupe de discussion (si chat de groupe)' })
  @IsOptional()
  @IsString()
  groupId?: string;

  @ApiProperty({ example: 'Bonjour Dr. Ben Amor, voici le bilan sanguin du patient Hadil.', description: 'Contenu du message' })
  @IsString()
  @IsNotEmpty()
  content: string;

  @ApiPropertyOptional({ enum: MessageType, example: MessageType.TEXT })
  @IsOptional()
  @IsEnum(MessageType)
  messageType?: MessageType;

  @ApiPropertyOptional({ type: [MessageAttachmentDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => MessageAttachmentDto)
  attachments?: MessageAttachmentDto[];
}

export class CallSignalDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID de l\'employé à appeler' })
  @IsMongoId()
  @IsNotEmpty()
  targetUserId: string;

  @ApiProperty({ example: 'AUDIO', description: 'Type d\'appel: AUDIO ou VIDEO' })
  @IsString()
  @IsNotEmpty()
  callType: 'AUDIO' | 'VIDEO';

  @ApiProperty({ example: 'INITIATE', description: 'Action: INITIATE, ANSWER, REJECT, END' })
  @IsString()
  @IsNotEmpty()
  action: 'INITIATE' | 'ANSWER' | 'REJECT' | 'END';
}

export class CreateGroupDto {
  @ApiProperty({ example: 'Équipe Garde Samedi', description: 'Nom du groupe personnalisable' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({ example: 'Coordination des gardes de nuit', description: 'Description optionnelle' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ example: ['60c72b2f9b1d8b2bad8e9a12'], description: 'Liste des IDs des membres du groupe' })
  @IsArray()
  @IsMongoId({ each: true })
  memberIds: string[];
}

export class BlockUserDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID de l\'utilisateur à bloquer/débloquer' })
  @IsMongoId()
  @IsNotEmpty()
  targetUserId: string;
}

export class ArchiveConversationDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12', description: 'ID de la conversation ou du membre' })
  @IsString()
  @IsNotEmpty()
  targetId: string;
}
