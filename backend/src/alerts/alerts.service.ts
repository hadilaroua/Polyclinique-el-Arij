import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { AlertLevel } from '../common/enums/alert-level.enum';
import { Role } from '../common/enums/role.enum';
import { CreateAlertDto } from './dto/alert.dto';
import { Alert, AlertDocument } from './schemas/alert.schema';

@Injectable()
export class AlertsService {
  constructor(
    @InjectModel(Alert.name) private alertModel: Model<AlertDocument>,
  ) {}

  async create(
    dto: CreateAlertDto,
    createdById: string,
  ): Promise<AlertDocument> {
    const validPatientId = dto.patientId && Types.ObjectId.isValid(dto.patientId) ? new Types.ObjectId(dto.patientId) : null;
    const validTargetDoctorId = dto.targetDoctorId && Types.ObjectId.isValid(dto.targetDoctorId) ? new Types.ObjectId(dto.targetDoctorId) : null;
    const validCreatedBy = createdById && Types.ObjectId.isValid(createdById) ? new Types.ObjectId(createdById) : null;

    const alert = new this.alertModel({
      ...dto,
      patientId: validPatientId,
      targetDoctorId: validTargetDoctorId,
      createdBy: validCreatedBy,
      targetRoles: dto.targetRoles || [Role.DOCTOR, Role.NURSE],
    });

    const populated = await (await alert.save()).populate([
      {
        path: 'patientId',
        populate: { path: 'userId', select: 'firstName lastName email' },
      },
      { path: 'createdBy', select: 'firstName lastName role' },
      { path: 'targetDoctorId', select: 'firstName lastName email' },
    ]);

    this.dispatchNativeSimulatorPush(populated);

    return populated;
  }

  private dispatchNativeSimulatorPush(alert: any) {
    if (process.platform !== 'darwin') return;

    try {
      const { exec } = require('child_process');
      const fs = require('fs');
      const path = require('path');

      const pat = alert.patientId?.userId || alert.patientId;
      const patName = pat
        ? `${pat.firstName || ''} ${pat.lastName || ''}`.trim()
        : 'Patient';

      const targetDoctorName = alert.targetDoctorId
        ? `Dr. ${alert.targetDoctorId.firstName || ''} ${alert.targetDoctorId.lastName || ''}`.trim()
        : null;

      const title = alert.level === 'CRITICAL'
        ? `🚨 [URGENCE VITALE] ${alert.title}`
        : `⚠️ [ALERTE MÉDICALE] ${alert.title}`;

      const body = targetDoctorName
        ? `Destiné à ${targetDoctorName} — Patient: ${patName} : ${alert.description || ''}`
        : `Patient: ${patName} : ${alert.description || ''}`;

      const apnsPayload = {
        'Simulator Target Bundle': 'tn.arij.frontend',
        aps: {
          alert: {
            title,
            body,
          },
          badge: 1,
          sound: 'default',
        },
      };

      const tmpFile = path.join('/tmp', `apns_${Date.now()}.json`);
      fs.writeFileSync(tmpFile, JSON.stringify(apnsPayload));

      exec('xcrun simctl list devices | grep -i booted', (err: any, stdout: string) => {
        if (err || !stdout) {
          try { fs.unlinkSync(tmpFile); } catch (_) {}
          return;
        }

        const matches = stdout.match(/\(([0-9A-F\-]{36})\)/gi);
        if (matches) {
          matches.forEach((m) => {
            const udid = m.replace(/[()]/g, '');
            exec(`xcrun simctl push ${udid} tn.arij.frontend ${tmpFile}`);
          });
        }

        setTimeout(() => {
          try { fs.unlinkSync(tmpFile); } catch (_) {}
        }, 6000);
      });
    } catch (_) {}
  }

  async findAll(query?: {
    level?: AlertLevel;
    isResolved?: boolean;
    patientId?: string;
    role?: Role;
    userId?: string;
  }): Promise<AlertDocument[]> {
    const filter: Record<string, any> = {};

    if (query?.level) filter.level = query.level;
    if (typeof query?.isResolved === 'boolean') {
      filter.isResolved = query.isResolved;
    }
    if (query?.patientId) {
      filter.patientId = new Types.ObjectId(query.patientId);
    }
    if (query?.role && query.role !== Role.ADMIN) {
      const orConditions: any[] = [];
      if (query.userId) {
        orConditions.push({ createdBy: new Types.ObjectId(query.userId) });
      }

      if (query.role === Role.DOCTOR && query.userId) {
        orConditions.push({
          targetRoles: Role.DOCTOR,
          $or: [
            { targetDoctorId: new Types.ObjectId(query.userId) },
            { targetDoctorId: null },
            { targetDoctorId: { $exists: false } },
          ],
        });
      } else {
        orConditions.push(
          { targetRoles: query.role },
          { targetRoles: { $exists: false } },
          { targetRoles: { $size: 0 } },
        );
      }

      filter.$or = orConditions;
    }

    return this.alertModel
      .find(filter)
      .populate([
        {
          path: 'patientId',
          populate: { path: 'userId', select: 'firstName lastName' },
        },
        { path: 'createdBy', select: 'firstName lastName role' },
        { path: 'targetDoctorId', select: 'firstName lastName email' },
        { path: 'resolvedBy', select: 'firstName lastName role' },
      ])
      .sort({ createdAt: -1 })
      .exec();
  }

  async findById(id: string): Promise<AlertDocument> {
    const alert = await this.alertModel
      .findById(id)
      .populate([
        {
          path: 'patientId',
          populate: { path: 'userId', select: 'firstName lastName' },
        },
        { path: 'createdBy', select: 'firstName lastName role' },
      ])
      .exec();

    if (!alert) {
      throw new NotFoundException(`Alerte introuvable avec l'ID ${id}`);
    }
    return alert;
  }

  async resolve(id: string, resolvedById: string): Promise<AlertDocument> {
    const alert = await this.findById(id);
    alert.isResolved = true;
    alert.resolvedBy = new Types.ObjectId(resolvedById) as any;
    alert.resolvedAt = new Date();
    return alert.save();
  }

  async resolveAll(
    userId: string,
    userRole: Role,
  ): Promise<{ count: number }> {
    const filter: Record<string, any> = { isResolved: false };
    if (userRole === Role.DOCTOR) {
      filter.$or = [
        { targetDoctorId: new Types.ObjectId(userId) },
        { targetDoctorId: null },
        { targetDoctorId: { $exists: false } },
        { createdBy: new Types.ObjectId(userId) },
      ];
    }

    const result = await this.alertModel.updateMany(filter, {
      $set: {
        isResolved: true,
        resolvedBy: new Types.ObjectId(userId),
        resolvedAt: new Date(),
      },
    });

    return { count: result.modifiedCount };
  }

  async countUnresolved(): Promise<number> {
    return this.alertModel.countDocuments({ isResolved: false }).exec();
  }
}
