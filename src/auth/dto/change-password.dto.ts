import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @ApiProperty({ example: 'OldPass123!' })
  @IsString()
  @IsNotEmpty()
  oldPassword: string;

  @ApiProperty({ example: 'NewPass456!' })
  @IsString()
  @MinLength(6, {
    message: 'Le nouveau mot de passe doit comporter au moins 6 caractères',
  })
  newPassword: string;
}
