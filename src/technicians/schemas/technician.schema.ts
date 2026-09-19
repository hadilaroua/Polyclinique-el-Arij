import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { User } from '../../users/schemas/user.schema';

export type TechnicianDocument = Technician & Document;

/**
 * Profil Technicien — Couvre : Radiologie, Scanner, Laboratoire, PMA, Bloc opératoire, etc.
 * Les catégories sont flexibles et configurables par l'Admin.
 */
@Schema({ timestamps: true })
export class Technician {
  @Prop({ type: Types.ObjectId, ref: User.name, required: true, unique: true })
  userId: Types.ObjectId;

  /**
   * Département technique principal
   * Exemples : Radiologie, Laboratoire, PMA, Bloc opératoire
   */
  @Prop({ required: true, trim: true })
  technicalDepartment: string;

  /**
   * Spécialité technique précise
   * Exemples : Scanner, IRM, Biologie, Bactériologie, Anesthésie
   */
  @Prop({ default: '', trim: true })
  technicalSpecialty: string;

  /** Service clinique d'appartenance */
  @Prop({ default: '', trim: true })
  service: string;

  /** Shift de travail */
  @Prop({ default: 'Matin (07h-15h)' })
  shift: string;

  /** Numéro d'enregistrement interne clinique */
  @Prop({ default: '', trim: true })
  registryId: string;

  @Prop({ default: true })
  isActive: boolean;
}

export const TechnicianSchema = SchemaFactory.createForClass(Technician);

TechnicianSchema.index({ technicalDepartment: 1 });
TechnicianSchema.index({ service: 1 });
TechnicianSchema.index({ isActive: 1 });
