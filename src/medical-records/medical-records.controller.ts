import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { PatientsService } from '../patients/patients.service';
import {
  ConsultationEntryDto,
  CreateMedicalRecordDto,
  TreatmentItemDto,
  UpdateMedicalRecordDto,
} from './dto/medical-record.dto';
import { MedicalRecordsService } from './medical-records.service';

@ApiTags('Dossier Médical Électronique (DME)')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('medical-records')
export class MedicalRecordsController {
  constructor(
    private readonly recordsService: MedicalRecordsService,
    private readonly patientsService: PatientsService,
  ) {}

  @Post()
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Créer un dossier médical pour un patient' })
  create(@Body() createDto: CreateMedicalRecordDto) {
    return this.recordsService.create(createDto);
  }

  @Get('my-record')
  @Roles(Role.PATIENT)
  @ApiOperation({
    summary: 'Consulter l’avancement administratif du parcours (sans résultats médicaux)',
  })
  async getMyRecord(@CurrentUser('sub') userId: string) {
    const patient = await this.patientsService.findByUserId(userId);
    if (!patient) {
      throw new ForbiddenException('Profil patient non trouvé');
    }
    const record = await this.recordsService.findByPatientId(patient._id.toString());

    return {
      patientId: patient._id,
      accessPolicy: 'Les diagnostics, prescriptions et résultats sont communiqués sur place à la clinique.',
      journey: {
        dossier: 'TERMINÉ',
        consultations: record?.consultations?.length ? 'TERMINÉ' : 'À VENIR',
        examens: record?.examinations?.length ? 'RÉSULTATS DISPONIBLES SUR PLACE' : 'À VENIR',
        traitements: record?.treatments?.length ? 'SUIVI EN COURS' : 'À VENIR',
      },
      history: (record?.consultations || []).map((consultation) => ({
        date: consultation.date,
        status: 'TERMINÉ',
      })),
      upcoming: [],
    };
  }

  @Get('patient/:patientId')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE)
  @ApiOperation({
    summary:
      'Consulter le dossier médical d’un patient (filtré selon le rôle)',
  })
  async getByPatientId(
    @Param('patientId') patientId: string,
    @CurrentUser('role') role: Role,
  ) {
    const record = await this.recordsService.findByPatientId(patientId);

    // Si c'est un infirmier, on filtre les données sensibles pour ne donner que les soins
    if (role === Role.NURSE) {
      return {
        patientId: record.patientId,
        allergies: record.allergies,
        antecedents: record.antecedents,
        treatments: record.treatments,
        examinations: record.examinations,
        isRestrictedView: true,
      };
    }

    return record;
  }

  @Patch('patient/:patientId')
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Mettre à jour le dossier médical' })
  update(
    @Param('patientId') patientId: string,
    @Body() updateDto: UpdateMedicalRecordDto,
  ) {
    return this.recordsService.update(patientId, updateDto);
  }

  @Post('patient/:patientId/consultations')
  @Roles(Role.DOCTOR)
  @ApiOperation({
    summary: 'Ajouter une consultation médicale (Médecin uniquement)',
  })
  addConsultation(
    @Param('patientId') patientId: string,
    @Body() consultationDto: ConsultationEntryDto,
  ) {
    return this.recordsService.addConsultation(patientId, consultationDto);
  }

  @Post('patient/:patientId/treatments')
  @Roles(Role.DOCTOR)
  @ApiOperation({ summary: 'Ajouter un traitement prescrit (Médecin uniquement)' })
  addTreatment(
    @Param('patientId') patientId: string,
    @Body() treatmentDto: TreatmentItemDto,
  ) {
    return this.recordsService.addTreatment(patientId, treatmentDto);
  }
}
