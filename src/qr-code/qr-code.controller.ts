import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { MedicalRecordsService } from '../medical-records/medical-records.service';
import { PatientsService } from '../patients/patients.service';
import { ScanQrDto } from './dto/scan-qr.dto';
import { QrCodeService } from './qr-code.service';

@ApiTags('Système QR Code')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('qr')
export class QrCodeController {
  constructor(
    private readonly qrCodeService: QrCodeService,
    private readonly patientsService: PatientsService,
    private readonly recordsService: MedicalRecordsService,
  ) {}

  @Post('scan')
  @HttpCode(HttpStatus.OK)
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE)
  @ApiOperation({
    summary:
      'Scanner un QR code patient et renvoyer les données autorisées selon le rôle soignant',
  })
  async scanPatientQr(
    @Body() scanDto: ScanQrDto,
    @CurrentUser('role') role: Role,
  ) {
    let patient;

    // Détection si c'est un format JSON encodé ou directement un token
    try {
      const payload = this.qrCodeService.parseQrPayload(scanDto.qrContent);
      patient = await this.patientsService.findByDossierNumber(
        payload.dossierNumber,
      );
    } catch {
      // Si ce n'est pas un JSON, on cherche par le token ou numéro de dossier
      const cleaned = scanDto.qrContent.trim();
      try {
        patient = await this.patientsService.findByQrToken(cleaned);
      } catch {
        patient = await this.patientsService.findByDossierNumber(cleaned);
      }
    }

    if (!patient) {
      throw new NotFoundException(
        'Patient non trouvé pour le code QR fourni',
      );
    }

    const patientUser: any = patient.userId;
    const medicalRecord = await this.recordsService.findByPatientId(
      patient._id.toString(),
    );

    // Cas 1 : Infirmier(ère) -> Vue restreinte d'urgence et soins
    if (role === Role.NURSE) {
      return {
        roleAuthorized: Role.NURSE,
        accessLevel: 'RESTRICTED_CARE',
        patient: {
          id: patient._id,
          dossierNumber: patient.dossierNumber,
          fullName: `${patientUser?.firstName || ''} ${patientUser?.lastName || ''}`.trim(),
          dateOfBirth: patient.dateOfBirth,
          gender: patient.gender,
          bloodType: patient.bloodType,
          emergencyContact: patient.emergencyContact,
        },
        allergies: medicalRecord.allergies,
        currentTreatments: medicalRecord.treatments,
        surgicalAntecedents: medicalRecord.antecedents?.surgical || [],
      };
    }

    // Cas 2 : Médecin ou Administrateur -> Vue médicale complète
    return {
      roleAuthorized: role,
      accessLevel: 'FULL_MEDICAL_ACCESS',
      patient: {
        id: patient._id,
        dossierNumber: patient.dossierNumber,
        firstName: patientUser?.firstName,
        lastName: patientUser?.lastName,
        email: patientUser?.email,
        phone: patientUser?.phone,
        dateOfBirth: patient.dateOfBirth,
        gender: patient.gender,
        bloodType: patient.bloodType,
        emergencyContact: patient.emergencyContact,
        address: patient.address,
      },
      medicalRecord,
    };
  }
}
