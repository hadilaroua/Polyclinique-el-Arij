import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { Doctor } from '../../doctors/schemas/doctor.schema';
import { Patient } from '../../patients/schemas/patient.schema';
import { User } from '../../users/schemas/user.schema';

export type ConsultationDocument = Consultation & Document;

/**
 * Consultation médicale — Entité indépendante (séparée du MedicalRecord monolithique).
 * Créée par un médecin lors d'une visite ou d'un suivi patient.
 */
@Schema({ timestamps: true })
export class Consultation {
  @Prop({ type: Types.ObjectId, ref: Patient.name, required: true })
  patientId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: User.name, required: true })
  doctorId: Types.ObjectId;

  /** Date de la consultation (format ISO) */
  @Prop({ required: true })
  date: string;

  /** Motif de la consultation */
  @Prop({ required: true, trim: true })
  motive: string;

  /** Symptômes rapportés */
  @Prop({ default: '', trim: true })
  symptoms: string;

  /** Examen clinique réalisé */
  @Prop({ default: '', trim: true })
  clinicalExam: string;

  /** Diagnostic posé */
  @Prop({ required: true, trim: true })
  diagnostic: string;

  /** Prescription médicamenteuse (résumé texte) */
  @Prop({ default: '', trim: true })
  prescription: string;

  /** Prescription structurée (médicament, dosage, posologie, fréquence, durée) */
  @Prop({
    type: [
      {
        medicine: { type: String, required: true },
        dosage: { type: String, default: '' },
        posology: { type: String, default: '' },
        frequency: { type: String, default: '' },
        duration: { type: String, default: '' },
        instructions: { type: String, default: '' },
      },
    ],
    default: [],
  })
  prescriptionItems: Array<{
    medicine: string;
    dosage: string;
    posology: string;
    frequency: string;
    duration: string;
    instructions?: string;
  }>;

  /** Documents et pièces jointes (ordonnance originale PDF/image, courriers, examens joints) */
  @Prop({
    type: [
      {
        name: { type: String, required: true },
        url: { type: String, required: true },
        fileType: { type: String, default: 'document' },
      },
    ],
    default: [],
  })
  attachments: Array<{
    name: string;
    url: string;
    fileType?: string;
  }>;

  /** Observations et notes médicales */
  @Prop({ default: '', trim: true })
  observations: string;

  /** Date de suivi planifiée */
  @Prop({ type: String, default: null })
  followUpDate: string | null;

  /** Notes de suivi */
  @Prop({ default: '', trim: true })
  followUpNotes: string;
}

export const ConsultationSchema = SchemaFactory.createForClass(Consultation);

ConsultationSchema.index({ patientId: 1 });
ConsultationSchema.index({ doctorId: 1 });
ConsultationSchema.index({ date: -1 });
