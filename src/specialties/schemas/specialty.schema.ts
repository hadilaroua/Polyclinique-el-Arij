import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type SpecialtyDocument = Specialty & Document;

export enum SpecialtyType {
  MEDICAL = 'MEDICAL',
  SURGICAL = 'SURGICAL',
  TECHNICAL = 'TECHNICAL',
}

/**
 * Entité Spécialité — Configurable par l'Admin.
 *
 * MEDICAL : Médecine générale, Cardiologie, Pédiatrie...
 * SURGICAL : Chirurgie vasculaire, Chirurgie viscérale...
 * TECHNICAL : Radiologie, Biologie, Anesthésie...
 */
@Schema({ timestamps: true })
export class Specialty {
  @Prop({ required: true, unique: true, trim: true })
  name: string;

  @Prop({ required: true, enum: SpecialtyType })
  type: SpecialtyType;

  @Prop({ default: '', trim: true })
  description: string;

  @Prop({ default: true })
  isActive: boolean;
}

export const SpecialtySchema = SchemaFactory.createForClass(Specialty);

SpecialtySchema.index({ type: 1 });
SpecialtySchema.index({ isActive: 1 });
