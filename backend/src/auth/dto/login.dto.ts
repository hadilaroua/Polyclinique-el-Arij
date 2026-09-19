import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class LoginDto {
  @ApiProperty({
    example: 'dr.karima@arij.tn',
    description: 'Adresse email du compte',
  })
  @IsString()
  @IsNotEmpty({
    message: 'L’adresse email est obligatoire',
  })
  email: string;

  @ApiProperty({ example: 'Admin123!' })
  @IsString()
  @IsNotEmpty({ message: 'Le mot de passe est obligatoire' })
  password: string;
}
