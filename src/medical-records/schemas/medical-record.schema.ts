import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { Patient } from '../../patients/schemas/patient.schema';

export type MedicalRecordDocument = MedicalRecord & Document;

@Schema({ _id: false })
export class TreatmentItem {
  @Prop({ required: true })
  medication: string;

  @Prop({ required: true })
  dosage: string;

  @Prop({ default: 'Quotidien' })
  frequency: string;

  @Prop({ default: () => new Date().toISOString() })
  startDate: string;

  @Prop({ default: null })
  endDate?: string;

  @Prop({ default: '' })
  prescribingDoctor?: string;
}

export const TreatmentItemSchema = SchemaFactory.createForClass(TreatmentItem);

@Schema({ _id: false })
export class ConsultationEntry {
  @Prop({ default: () => new Date().toISOString() })
  date: string;

  @Prop({ required: true })
  doctorName: string;

  @Prop({ default: 'Médecine Générale' })
  doctorSpecialty: string;

  @Prop({ required: true })
  motive: string;

  @Prop({ required: true })
  diagnostic: string;

  @Prop({ default: '' })
  prescription: string;

  @Prop({ default: '' })
  observations: string;
}

export const ConsultationEntrySchema =
  SchemaFactory.createForClass(ConsultationEntry);

@Schema({ _id: false })
export class ExaminationItem {
  @Prop({ required: true })
  type: string; // Ex: Prise de sang, ECG, Radio, Échographie

  @Prop({ default: () => new Date().toISOString() })
  date: string;

  @Prop({ required: true })
  results: string;

  @Prop({ default: 'Polyclinique Arij Midoun' })
  laboratory: string;
}

export const ExaminationItemSchema =
  SchemaFactory.createForClass(ExaminationItem);

@Schema({ timestamps: true })
export class MedicalRecord {
  @Prop({ type: Types.ObjectId, ref: Patient.name, required: true, unique: true })
  patientId: Types.ObjectId;

  @Prop({ type: [String], default: [] })
  allergies: string[];

  @Prop({
    type: {
      personal: [String],
      family: [String],
      surgical: [String],
    },
    default: { personal: [], family: [], surgical: [] },
  })
  antecedents: {
    personal: string[];
    family: string[];
    surgical: string[];
  };

  @Prop({ type: [TreatmentItemSchema], default: [] })
  treatments: TreatmentItem[];

  @Prop({ type: [ConsultationEntrySchema], default: [] })
  consultations: ConsultationEntry[];

  @Prop({ type: [ExaminationItemSchema], default: [] })
  examinations: ExaminationItem[];

  @Prop({ default: '' })
  generalNotes: string;
}

export const MedicalRecordSchema = SchemaFactory.createForClass(MedicalRecord);

