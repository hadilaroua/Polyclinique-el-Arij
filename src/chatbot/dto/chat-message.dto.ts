import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class ChatMessageDto {
  @ApiProperty({
    example: 'Quels sont les horaires de consultation à la clinique ?',
    description: 'La question posée par l’utilisateur au chatbot de la clinique',
  })
  @IsString()
  @IsNotEmpty({ message: 'Le message ou la question ne peut pas être vide' })
  message: string;
}
