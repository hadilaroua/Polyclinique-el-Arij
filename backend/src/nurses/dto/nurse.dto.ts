import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsMongoId,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateNurseDto {
  @ApiProperty({ example: '60c72b2f9b1d8b2bad8e9a12' })
  @IsMongoId()
  @IsNotEmpty()
  userId: string;

  @ApiProperty({ example: 'Service Urgences' })
  @IsString()
  @IsNotEmpty({ message: 'Le département est obligatoire' })
  department: string;

  @ApiPropertyOptional({ example: 'Matin (07h-15h)' })
  @IsOptional()
  @IsString()
  shift?: string;

  @ApiPropertyOptional({ example: ['Chambre 101', 'Chambre 102'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  assignedRooms?: string[];
}

export class UpdateNurseDto {
  @ApiPropertyOptional({ example: 'Service Réanimation' })
  @IsOptional()
  @IsString()
  department?: string;

  @ApiPropertyOptional({ example: 'Garde de nuit (21h-08h)' })
  @IsOptional()
  @IsString()
  shift?: string;

  @ApiPropertyOptional({ example: ['Chambre 201', 'Chambre 202'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  assignedRooms?: string[];

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;
}
