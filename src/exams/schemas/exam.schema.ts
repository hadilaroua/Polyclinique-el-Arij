import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { Doctor } from '../../doctors/schemas/doctor.schema';
import { Patient } from '../../patients/schemas/patient.schema';
import { Technician } from '../../technicians/schemas/technician.schema';

export type ExamDocument = Exam & Document;

export enum ExamStatus {
  PENDING = 'PENDING',
  IN_PROGRESS = 'IN_PROGRESS',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
}

export enum ExamPriority {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
  URGENT = 'URGENT',
}

/**
 * Demande d'examen + résultat — Workflow : PENDING → IN_PROGRESS → COMPLETED
 *
 * Le médecin crée la demande.
 * Le technicien la prend en charge et saisit le résultat.
 * Le médecin est notifié à la validation.
 */
@Schema({ timestamps: true })
export class Exam {
  // --- Demande ---
  @Prop({ type: Types.ObjectId, ref: Patient.name, required: true })
  patientId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: Doctor.name, required: false, default: null })
  requestingDoctorId?: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: Technician.name, default: null })
  assignedTechnicianId?: Types.ObjectId;

  @Prop({ required: true, trim: true })
  examType: string; // Ex: 'Prise de sang', 'ECG', 'Scanner thoracique'

  @Prop({ default: '', trim: true })
  service: string; // Service qui prend en charge

  @Prop({ required: true, enum: ExamPriority, default: ExamPriority.MEDIUM })
  priority: ExamPriority;

  @Prop({ required: true, enum: ExamStatus, default: ExamStatus.PENDING })
  status: ExamStatus;

  @Prop({ default: '', trim: true })
  requestNotes: string; // Notes du médecin lors de la demande

  // --- Traitement par le technicien ---
  @Prop({ type: Date, default: null })
  startedAt?: Date;

  @Prop({ default: '', trim: true })
  technicalNotes: string; // Notes internes du technicien

  // --- Résultat ---
  @Prop({ default: '', trim: true })
  result: string; // Résultat de l'examen

  @Prop({ default: '', trim: true })
  resultDocumentUrl?: string; // Pièce jointe du résultat (PDF, image ECG/scanner, compte rendu)

  @Prop({ type: Date, default: null })
  completedAt?: Date;

  // --- Suppression & Archivage ---
  @Prop({ type: [String], default: [] })
  softDeletedByUserIds: string[];

  @Prop({ default: false })
  isSoftDeleted: boolean;
}

export const ExamSchema = SchemaFactory.createForClass(Exam);

ExamSchema.index({ patientId: 1 });
ExamSchema.index({ requestingDoctorId: 1 });
ExamSchema.index({ assignedTechnicianId: 1 });
ExamSchema.index({ status: 1 });
ExamSchema.index({ priority: 1 });
