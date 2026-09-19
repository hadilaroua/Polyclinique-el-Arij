import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { Role } from '../../common/enums/role.enum';
import { Patient } from '../../patients/schemas/patient.schema';
import { User } from '../../users/schemas/user.schema';

export type AuditLogDocument = AuditLog & Document;

@Schema({ timestamps: true })
export class AuditLog {
  @Prop({ required: true, trim: true })
  action: string; // Ex: 'CREATION_CONSULTATION', 'VALIDATION_EXAMEN', 'PRISE_CONSTANTES'

  @Prop({ default: 'CLINIQUE', trim: true })
  category: string; // Ex: 'CONSULTATION', 'EXAMEN', 'SOINS', 'ALERTE', 'HOSPITALISATION'

  @Prop({ type: Types.ObjectId, ref: User.name, required: true })
  actorId: Types.ObjectId;

  @Prop({ required: true, trim: true })
  actorName: string; // Ex: 'Dr. Rachid Aroua'

  @Prop({ required: true, enum: Role })
  actorRole: Role;

  @Prop({ type: Types.ObjectId, ref: Patient.name, default: null })
  patientId?: Types.ObjectId;

  @Prop({ default: '', trim: true })
  patientName?: string;

  @Prop({ default: '', trim: true })
  patientDossier?: string; // Ex: 'PAT-2026-00125'

  @Prop({ default: '', trim: true })
  entityId?: string;

  @Prop({ default: '', trim: true })
  targetEntity?: string; // Ex: 'Consultation', 'Exam', 'VitalSigns'

  @Prop({ default: '', trim: true })
  details: string;

  @Prop({ type: Object, default: {} })
  metadata?: Record<string, any>;
}

export const AuditLogSchema = SchemaFactory.createForClass(AuditLog);

AuditLogSchema.index({ createdAt: -1 });
AuditLogSchema.index({ actorId: 1 });
AuditLogSchema.index({ patientId: 1 });
AuditLogSchema.index({ category: 1 });
AuditLogSchema.index({ action: 1 });
