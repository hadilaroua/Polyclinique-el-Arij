import { BadRequestException, Injectable } from '@nestjs/common';
import * as QRCode from 'qrcode';

export interface QrCodePayload {
  patientId: string;
  dossierNumber: string;
  token: string;
  clinic: string;
}

@Injectable()
export class QrCodeService {
  private readonly clinicIdentifier = 'POLYCLINIQUE_ARIJ_DJERBA';

  /**
   * Génère une image QR Code sous forme de DataURL Base64
   */
  async generateQrCodeDataUrl(
    patientId: string,
    dossierNumber: string,
    token: string,
  ): Promise<string> {
    const payload: QrCodePayload = {
      patientId,
      dossierNumber,
      token,
      clinic: this.clinicIdentifier,
    };

    try {
      const dataString = JSON.stringify(payload);
      const dataUrl = await QRCode.toDataURL(dataString, {
        errorCorrectionLevel: 'H',
        margin: 2,
        width: 300,
        color: {
          dark: '#0f4c81', // Bleu médical de la clinique
          light: '#ffffff',
        },
      });
      return dataUrl;
    } catch (error) {
      throw new BadRequestException(
        `Échec de génération du code QR : ${error.message}`,
      );
    }
  }

  /**
   * Valide et décode le contenu scanné d'un QR Code patient
   */
  parseQrPayload(rawContent: string): QrCodePayload {
    try {
      const parsed = JSON.parse(rawContent) as QrCodePayload;
      if (!parsed.patientId || !parsed.dossierNumber) {
        throw new Error('Champs obligatoires manquants');
      }
      return parsed;
    } catch {
      throw new BadRequestException(
        'Format de code QR invalide ou non reconnu par la clinique Arij',
      );
    }
  }
}
