import { Injectable, NotFoundException, Optional } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { AlertsService } from '../alerts/alerts.service';
import { AuditLogsService } from '../audit-logs/audit-logs.service';
import { AlertLevel } from '../common/enums/alert-level.enum';
import { Role } from '../common/enums/role.enum';
import { CreateVitalSignDto } from './dto/vital-sign.dto';
import { VitalSign, VitalSignDocument } from './schemas/vital-sign.schema';

@Injectable()
export class VitalSignsService {
  constructor(
    @InjectModel(VitalSign.name) private vitalSignModel: Model<VitalSignDocument>,
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

  async findAll(limit = 50): Promise<VitalSignDocument[]> {
    return this.vitalSignModel
      .find()
      .populate('patientId', 'firstName lastName cin dossierNumber')
      .populate('recordedByUserId', 'firstName lastName role')
      .sort({ recordedAt: -1 })
      .limit(limit)
      .exec();
  }

  async findByPatient(patientId: string, limit = 50): Promise<VitalSignDocument[]> {
    return this.vitalSignModel
      .find({ patientId })
      .populate('recordedByUserId', 'firstName lastName role')
      .sort({ recordedAt: -1 })
      .limit(limit)
      .exec();
  }

  async findLatestByPatient(patientId: string): Promise<VitalSignDocument | null> {
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
