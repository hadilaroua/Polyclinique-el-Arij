import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsMongoId, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateNotificationDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12' })
  @IsMongoId()
  @IsNotEmpty()
  recipientUserId: string;

  @ApiProperty({ example: 'Rappel de Rendez-vous' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({
    example:
      '🔔 Votre rendez-vous avec le Dr. Ben Salem est prévu demain à 10h00.',
  })
  @IsString()
  @IsNotEmpty()
  body: string;

  @ApiPropertyOptional({ example: 'APPOINTMENT' })
  @IsOptional()
  @IsString()
  type?: string;

  @ApiPropertyOptional({ example: '60c72b2f9b1d8b2bad8e9a99' })
  @IsOptional()
  @IsString()
  relatedId?: string;
}
