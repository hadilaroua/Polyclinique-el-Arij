import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { AppointmentStatus } from '../../common/enums/appointment-status.enum';
import { Doctor } from '../../doctors/schemas/doctor.schema';
import { Patient } from '../../patients/schemas/patient.schema';

export type AppointmentDocument = Appointment & Document;

@Schema({ timestamps: true })
export class Appointment {
  @Prop({ type: Types.ObjectId, ref: Patient.name, required: true })
  patientId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: Doctor.name, required: true })
  doctorId: Types.ObjectId;

  @Prop({ required: true })
  date: string; // Format YYYY-MM-DD

  @Prop({ required: true })
  timeSlot: string; // Ex: '10:00'

  @Prop({
    required: true,
    enum: AppointmentStatus,
    default: AppointmentStatus.PENDING,
  })
  status: AppointmentStatus;

  @Prop({ required: true })
  reason: string;

  @Prop({ default: '' })
  notes: string;

  @Prop({ default: '' })
  cancellationReason?: string;
}

export const AppointmentSchema = SchemaFactory.createForClass(Appointment);

AppointmentSchema.index({ patientId: 1 });
AppointmentSchema.index({ doctorId: 1 });
AppointmentSchema.index({ date: 1, timeSlot: 1, doctorId: 1 });
