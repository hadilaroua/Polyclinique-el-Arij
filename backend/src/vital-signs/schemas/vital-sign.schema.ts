import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { Patient } from '../../patients/schemas/patient.schema';
import { User } from '../../users/schemas/user.schema';

export type VitalSignDocument = VitalSign & Document;

/**
 * Constantes vitales d'un patient — Saisies par infirmier ou sage-femme.
 */
@Schema({ timestamps: true })
export class VitalSign {
  @Prop({ type: Types.ObjectId, ref: Patient.name, required: true })
  patientId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: User.name, required: true })
  recordedByUserId: Types.ObjectId; // Infirmier ou sage-femme

  /** Température en degrés Celsius */
  @Prop({ type: Number, default: null })
  temperature: number | null;

  /** Fréquence cardiaque (battements/min) */
  @Prop({ type: Number, default: null })
  heartRate: number | null;

  /** Tension artérielle systolique (mmHg) */
  @Prop({ type: Number, default: null })
  bloodPressureSystolic: number | null;

  /** Tension artérielle diastolique (mmHg) */
  @Prop({ type: Number, default: null })
  bloodPressureDiastolic: number | null;

  /** Saturation en oxygène SpO2 (%) */
  @Prop({ type: Number, default: null })
  oxygenSaturation: number | null;

  /** Fréquence respiratoire (cycles/min) */
  @Prop({ type: Number, default: null })
  respiratoryRate: number | null;

  /** Poids en kg */
  @Prop({ type: Number, default: null })
  weight: number | null;

  /** Taille en cm */
  @Prop({ type: Number, default: null })
  height: number | null;

  /** Glycémie (g/L ou mmol/L) */
  @Prop({ type: Number, default: null })
  bloodGlucose: number | null;

  @Prop({ default: '', trim: true })
  notes: string;

  @Prop({ required: true })
  recordedAt: Date;
}

export const VitalSignSchema = SchemaFactory.createForClass(VitalSign);

VitalSignSchema.index({ patientId: 1 });
VitalSignSchema.index({ recordedAt: -1 });
VitalSignSchema.index({ recordedByUserId: 1 });
