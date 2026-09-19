import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Role } from '../common/enums/role.enum';
import { CreateAuditLogDto } from './dto/audit-log.dto';
import { AuditLog, AuditLogDocument } from './schemas/audit-log.schema';

@Injectable()
export class AuditLogsService {
  constructor(
    @InjectModel(AuditLog.name) private auditLogModel: Model<AuditLogDocument>,
  ) {}

  async create(dto: CreateAuditLogDto): Promise<AuditLogDocument> {
    const log = new this.auditLogModel(dto);
    return log.save();
  }

  /**
   * Helper simplifié pour enregistrer un acte clinique depuis n'importe quel service
   */
  async recordAction(params: {
    action: string;
    category?: string;
    actorId: string | Types.ObjectId;
    actorName: string;
    actorRole: Role;
    patientId?: string | Types.ObjectId;
    patientName?: string;
    patientDossier?: string;
    entityId?: string;
    targetEntity?: string;
    details?: string;
    metadata?: Record<string, any>;
  }): Promise<AuditLogDocument> {
    const log = new this.auditLogModel({
      ...params,
      category: params.category || 'CLINIQUE',
      details: params.details || '',
    });
    return log.save();
  }

  async findAll(query: {
    category?: string;
    actorId?: string;
    patientId?: string;
    action?: string;
    limit?: number;
  } = {}): Promise<AuditLogDocument[]> {
    const filter: Record<string, any> = {};
    if (query.category) filter.category = query.category;
    if (query.actorId) filter.actorId = query.actorId;
    if (query.patientId) filter.patientId = query.patientId;
    if (query.action) filter.action = query.action;

    const limit = query.limit || 100;
    return this.auditLogModel
      .find(filter)
      .sort({ createdAt: -1 })
      .limit(limit)
      .exec();
  }

  async findByPatient(patientId: string): Promise<AuditLogDocument[]> {
    return this.auditLogModel
      .find({ patientId })
      .sort({ createdAt: -1 })
      .exec();
  }

  async findByActor(actorId: string): Promise<AuditLogDocument[]> {
    return this.auditLogModel
      .find({ actorId })
      .sort({ createdAt: -1 })
      .exec();
  }
}
