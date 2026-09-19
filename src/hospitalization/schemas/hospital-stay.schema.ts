import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { Doctor } from '../../doctors/schemas/doctor.schema';
import { Patient } from '../../patients/schemas/patient.schema';
import { Bed } from './bed.schema';

export type HospitalStayDocument = HospitalStay & Document;

export enum StayStatus {
  ACTIVE = 'ACTIVE',
  DISCHARGED = 'DISCHARGED',
  TRANSFERRED = 'TRANSFERRED',
}

@Schema({ timestamps: true })
export class HospitalStay {
  @Prop({ type: Types.ObjectId, ref: Patient.name, required: true })
  patientId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: Bed.name, required: true })
  bedId: Types.ObjectId;

  @Prop({ required: true, trim: true })
  service: string;

  @Prop({ type: Types.ObjectId, ref: Doctor.name, default: null })
  admittedByDoctorId?: Types.ObjectId;

  @Prop({ required: true })
  admissionDate: Date;

  @Prop({ type: Date, default: null })
  dischargeDate?: Date;

  @Prop({ default: '', trim: true })
  admissionReason: string;

  @Prop({ default: '', trim: true })
  dischargeNotes: string;

  @Prop({ required: true, enum: StayStatus, default: StayStatus.ACTIVE })
  status: StayStatus;
}

export const HospitalStaySchema = SchemaFactory.createForClass(HospitalStay);

HospitalStaySchema.index({ patientId: 1 });
HospitalStaySchema.index({ bedId: 1 });
HospitalStaySchema.index({ status: 1 });
HospitalStaySchema.index({ admissionDate: -1 });
