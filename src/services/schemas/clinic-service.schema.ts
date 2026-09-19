import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type ClinicServiceDocument = ClinicService & Document;

/**
 * Entité Service / Département de la clinique — Configurable par l'Admin.
 *
 * Exemples : Urgences, Réanimation, Maternité, Bloc opératoire,
 * Radiologie, Laboratoire, PMA, MPR, Hospitalisation, Consultations
 */
@Schema({ timestamps: true })
export class ClinicService {
  @Prop({ required: true, unique: true, trim: true })
  name: string;

  @Prop({ default: '', trim: true })
  description: string;

  @Prop({ default: 'medical-services' })
  icon: string;

  /** Couleur d'identification dans l'interface (HEX ou nom CSS) */
  @Prop({ default: '#2DB9BB' })
  color: string;

  @Prop({ default: true })
  isActive: boolean;

  /** Ordre d'affichage dans l'interface */
  @Prop({ default: 0 })
  displayOrder: number;
}

export const ClinicServiceSchema = SchemaFactory.createForClass(ClinicService);

ClinicServiceSchema.index({ name: 1 });
ClinicServiceSchema.index({ isActive: 1 });
ClinicServiceSchema.index({ displayOrder: 1 });
