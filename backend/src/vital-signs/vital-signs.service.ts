import { Injectable, NotFoundException, Optional } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { AlertsService } from '../alerts/alerts.service';
import { AuditLogsService } from '../audit-logs/audit-logs.service';
import { AlertLevel } from '../common/enums/alert-level.enum';
import { Role } from '../common/enums/role.enum';
import { CreateVitalSignDto } from './dto/vital-sign.dto';
import { VitalSign, VitalSignDocument } from './schemas/vital-sign.schema';
import { Patient, PatientDocument } from '../patients/schemas/patient.schema';
import { User, UserDocument } from '../users/schemas/user.schema';

@Injectable()
export class VitalSignsService {
  constructor(
    @InjectModel(VitalSign.name) private vitalSignModel: Model<VitalSignDocument>,
    @Optional() @InjectModel(Patient.name) private patientModel?: Model<PatientDocument>,
    @Optional() @InjectModel(User.name) private userModel?: Model<UserDocument>,
    @Optional() private alertsService?: AlertsService,
    @Optional() private auditLogsService?: AuditLogsService,
  ) {}

  async create(dto: CreateVitalSignDto): Promise<VitalSignDocument> {
    const record = new this.vitalSignModel({
      ...dto,
      recordedAt: dto.recordedAt ? new Date(dto.recordedAt) : new Date(),
    });
    const saved = await record.save();
    const populated = await saved.populate('recordedByUserId', 'firstName lastName role');

    const actor: any = populated.recordedByUserId;
    const actorName = actor ? `${actor.firstName || ''} ${actor.lastName || ''}`.trim() : 'Soignant';
    const actorRole = (actor?.role as Role) || Role.NURSE;

    // Détection automatique d'anomalies cliniques pour alerte immédiate
    const anomalies: string[] = [];
    let isCritical = false;

    if (dto.temperature && dto.temperature >= 38.5) {
      anomalies.push(`Fièvre élevée (${dto.temperature}°C)`);
      if (dto.temperature >= 39.5) isCritical = true;
    }
    if (dto.oxygenSaturation && dto.oxygenSaturation < 92) {
      anomalies.push(`Désaturation SpO2 (${dto.oxygenSaturation}%)`);
      if (dto.oxygenSaturation < 88) isCritical = true;
    }
    if (dto.heartRate && (dto.heartRate > 120 || dto.heartRate < 50)) {
      anomalies.push(`Fréquence cardiaque anormale (${dto.heartRate} bpm)`);
    }

    if (anomalies.length > 0 && this.alertsService) {
      this.alertsService
        .create(
          {
            patientId: dto.patientId,
            level: isCritical ? AlertLevel.CRITICAL : AlertLevel.WARNING,
            title: `Alerte Constantes Vitales : ${anomalies.join(', ')}`,
            description: `Constantes anormales enregistrées par ${actorName} : ${anomalies.join(' | ')}. ${dto.notes ? 'Observations : ' + dto.notes : ''}`,
            category: 'Surveillance Constantes',
            targetRoles: [Role.DOCTOR, Role.NURSE],
          },
          dto.recordedByUserId || actor?._id?.toString() || '',
        )
        .catch(() => {});
    }

    // Traçabilité AuditLog
    if (this.auditLogsService) {
      this.auditLogsService.recordAction({
        action: 'PRISE_CONSTANTES',
        category: 'SOINS',
        actorId: dto.recordedByUserId || actor?._id?.toString() || 'SYSTEM',
        actorName,
        actorRole,
        patientId: dto.patientId,
        entityId: saved._id.toString(),
        targetEntity: 'VitalSign',
        details: `Constantes saisies : T° ${dto.temperature ?? '-'}°C, FC ${dto.heartRate ?? '-'} bpm, TA ${dto.bloodPressureSystolic ?? '-'}/${dto.bloodPressureDiastolic ?? '-'}, SpO2 ${dto.oxygenSaturation ?? '-'}%`,
        metadata: {
          anomalies,
        },
      }).catch(() => {});
    }

    return populated;
  }

  async seedDefaultsIfEmpty(): Promise<void> {
    try {
      const count = await this.vitalSignModel.countDocuments({ patientId: { $ne: null } }).exec();
      if (count === 0) {
        await this.vitalSignModel.deleteMany({ patientId: null }).exec();
        let nurseId: any = null;
        if (this.userModel) {
          const nurse = await this.userModel.findOne({ email: 'sonia.infirmiere@arij.tn' }).exec();
          if (nurse) nurseId = nurse._id;
        }

        let existingPatients: any[] = [];
        if (this.patientModel) {
          existingPatients = await this.patientModel.find().exec();
        }

        const now = new Date();
        const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000);
        const fourHoursAgo = new Date(now.getTime() - 4 * 60 * 60 * 1000);
        const yesterdayEvening = new Date(now.getTime() - 18 * 60 * 60 * 1000);

        const defaults: any[] = [
          {
            patientId: existingPatients[0]?._id || 'pat_chirurgie_01',
            recordedByUserId: nurseId || new Types.ObjectId(),
            temperature: 37.0,
            heartRate: 74,
            bloodPressureSystolic: 120,
            bloodPressureDiastolic: 78,
            oxygenSaturation: 99,
            respiratoryRate: 16,
            weight: 74.0,
            height: 178,
            bloodGlucose: 1.05,
            notes: 'Surveillance post-op J+2 cœlioscopie. Paramètres hémodynamiques et respiratoires strictement normaux. Pansement propre, apyrétique, EVA douleur 1/10.',
            recordedAt: twoHoursAgo,
          },
          {
            patientId: existingPatients[1]?._id || 'pat_maternite_02',
            recordedByUserId: nurseId || new Types.ObjectId(),
            temperature: 36.9,
            heartRate: 76,
            bloodPressureSystolic: 115,
            bloodPressureDiastolic: 72,
            oxygenSaturation: 99,
            respiratoryRate: 16,
            weight: 68.5,
            height: 165,
            bloodGlucose: 0.92,
            notes: 'Surveillance prénatale 36 SA. Constantes maternelles optimales, absence d\'œdème pathologique, BCF fœtaux réguliers à 140 bpm.',
            recordedAt: twoHoursAgo,
          },
          {
            patientId: existingPatients[2]?._id || 'pat_cardio_03',
            recordedByUserId: nurseId || new Types.ObjectId(),
            temperature: 36.8,
            heartRate: 68,
            bloodPressureSystolic: 132,
            bloodPressureDiastolic: 82,
            oxygenSaturation: 98,
            respiratoryRate: 15,
            weight: 82.0,
            height: 175,
            bloodGlucose: 1.20,
            notes: 'Post-angioplastie coronaire J+3. Rythme régulier, bonne tolérance hémodynamique, pas de douleur thoracique ni dyspnée.',
            recordedAt: fourHoursAgo,
          },
          {
            patientId: existingPatients[3]?._id || 'pat_pediatrie_04',
            recordedByUserId: nurseId || new Types.ObjectId(),
            temperature: 38.3,
            heartRate: 108,
            bloodPressureSystolic: 102,
            bloodPressureDiastolic: 64,
            oxygenSaturation: 97,
            respiratoryRate: 22,
            weight: 14.5,
            height: 98,
            bloodGlucose: 0.95,
            notes: 'Épisode fébrile modéré à 38.3°C. Enfant tonique, hydratation surveillée per os, paracétamol sirop administré.',
            recordedAt: fourHoursAgo,
          },
          {
            patientId: existingPatients[4]?._id || 'pat_pma_05',
            recordedByUserId: nurseId || new Types.ObjectId(),
            temperature: 36.8,
            heartRate: 72,
            bloodPressureSystolic: 118,
            bloodPressureDiastolic: 74,
            oxygenSaturation: 100,
            respiratoryRate: 15,
            weight: 61.0,
            height: 168,
            bloodGlucose: 0.96,
            notes: 'Contrôle pré-opératoire ponction ovarienne. Constantes hémodynamiques et respiratoires parfaites.',
            recordedAt: fourHoursAgo,
          },
          {
            patientId: existingPatients[0]?._id || 'pat_chirurgie_01',
            recordedByUserId: nurseId || new Types.ObjectId(),
            temperature: 37.4,
            heartRate: 82,
            bloodPressureSystolic: 126,
            bloodPressureDiastolic: 80,
            oxygenSaturation: 98,
            respiratoryRate: 17,
            weight: 74.0,
            height: 178,
            bloodGlucose: 1.12,
            notes: 'Contrôle de soirée J+1. Transit repris sous forme de gaz, patient levé dans la chambre sans vertige.',
            recordedAt: yesterdayEvening,
          },
        ];

        await this.vitalSignModel.insertMany(defaults);
      }
    } catch (_) {}
  }

  async findAll(limit = 50): Promise<VitalSignDocument[]> {
    await this.seedDefaultsIfEmpty();
    return this.vitalSignModel
      .find()
      .populate('patientId', 'firstName lastName cin dossierNumber department')
      .populate('recordedByUserId', 'firstName lastName role')
      .sort({ recordedAt: -1 })
      .limit(limit)
      .exec();
  }

  async findByPatient(patientId: string, limit = 50): Promise<VitalSignDocument[]> {
    await this.seedDefaultsIfEmpty();
    return this.vitalSignModel
      .find({ patientId })
      .populate('recordedByUserId', 'firstName lastName role')
      .sort({ recordedAt: -1 })
      .limit(limit)
      .exec();
  }

  async findLatestByPatient(patientId: string): Promise<VitalSignDocument | null> {
    await this.seedDefaultsIfEmpty();
    return this.vitalSignModel
      .findOne({ patientId })
      .populate('recordedByUserId', 'firstName lastName')
      .sort({ recordedAt: -1 })
      .exec();
  }

  async findById(id: string): Promise<VitalSignDocument> {
    const record = await this.vitalSignModel
      .findById(id)
      .populate('recordedByUserId', 'firstName lastName role')
      .exec();
    if (!record) {
      throw new NotFoundException(`Constantes vitales introuvables avec l'ID : ${id}`);
    }
    return record;
  }

  async remove(id: string): Promise<{ message: string }> {
    const record = await this.vitalSignModel.findByIdAndDelete(id).exec();
    if (!record) {
      throw new NotFoundException(`Constantes vitales introuvables avec l'ID : ${id}`);
    }
    return { message: 'Enregistrement de constantes vitales supprimé' };
  }
}
