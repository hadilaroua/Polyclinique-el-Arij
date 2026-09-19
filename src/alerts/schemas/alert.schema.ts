import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { AlertLevel } from '../../common/enums/alert-level.enum';
import { Role } from '../../common/enums/role.enum';
import { Patient } from '../../patients/schemas/patient.schema';
import { User } from '../../users/schemas/user.schema';

export type AlertDocument = Alert & Document;

@Schema({ timestamps: true })
export class Alert {
  @Prop({ type: Types.ObjectId, ref: Patient.name, default: null })
  patientId?: Types.ObjectId;

  @Prop({
    required: true,
    enum: AlertLevel,
    default: AlertLevel.INFO,
  })
  level: AlertLevel;

  @Prop({ required: true, trim: true })
  title: string;

  @Prop({ required: true, trim: true })
  description: string;

  @Prop({ default: 'Surveillance Médicale' })
  category: string;

  @Prop({ type: [String], enum: Role, default: [Role.DOCTOR, Role.NURSE] })
  targetRoles: Role[];

  @Prop({ type: Types.ObjectId, ref: User.name, default: null })
  targetDoctorId?: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: User.name, required: true })
  createdBy: Types.ObjectId;

  @Prop({ default: false })
  isResolved: boolean;

  @Prop({ type: Types.ObjectId, ref: User.name, default: null })
  resolvedBy?: Types.ObjectId;

  @Prop({ default: null })
  resolvedAt?: Date;
}

export const AlertSchema = SchemaFactory.createForClass(Alert);

AlertSchema.index({ level: 1 });
AlertSchema.index({ isResolved: 1 });
AlertSchema.index({ patientId: 1 });
AlertSchema.index({ targetRoles: 1 });
