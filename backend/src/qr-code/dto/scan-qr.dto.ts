import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class ScanQrDto {
  @ApiProperty({
    example:
      '{"patientId":"60c72b2f9b1d8b2bad8e9a12","dossierNumber":"ARIJ-PAT-2026-0001","token":"QR_1710000000","clinic":"POLYCLINIQUE_ARIJ_DJERBA"}',
    description: 'Contenu brut scanné depuis le QR Code du patient ou le token',
  })
  @IsString()
  @IsNotEmpty({ message: 'Le contenu du QR code est requis' })
  qrContent: string;
}
