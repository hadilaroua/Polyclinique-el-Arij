import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { User } from '../../users/schemas/user.schema';

export type DoctorDocument = Doctor & Document;

@Schema({ _id: false })
export class ScheduleSlot {
  @Prop({
    required: true,
    enum: [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ],
  })
  dayOfWeek: string;

  @Prop({ required: true, example: '08:00' })
  startTime: string;

  @Prop({ required: true, example: '14:00' })
  endTime: string;

  @Prop({ default: 15 })
  maxPatients: number;

  @Prop({ default: true })
  isActive: boolean;
}

export const ScheduleSlotSchema = SchemaFactory.createForClass(ScheduleSlot);

@Schema({ timestamps: true })
export class Doctor {
  @Prop({ type: Types.ObjectId, ref: User.name, required: true, unique: true })
  userId: Types.ObjectId;

  @Prop({ required: true, trim: true })
  specialty: string;

  @Prop({ required: true, unique: true, trim: true })
  licenseNumber: string;

  @Prop({ required: true, trim: true })
  service: string; // Ex: Cardiologie, Pédiatrie, etc.

  @Prop({ default: 'Cabinet de consultation' })
  officeRoom: string;

  @Prop({ default: '' })
  biography: string;

  @Prop({ default: 50 })
  consultationFee: number;

  @Prop({ default: true })
  isAvailable: boolean;

  @Prop({ type: [ScheduleSlotSchema], default: [] })
  schedules: ScheduleSlot[];
}

export const DoctorSchema = SchemaFactory.createForClass(Doctor);

DoctorSchema.index({ specialty: 1 });
DoctorSchema.index({ service: 1 });
DoctorSchema.index({ isAvailable: 1 });

