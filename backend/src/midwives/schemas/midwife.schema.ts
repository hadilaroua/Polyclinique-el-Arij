import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { User } from '../../users/schemas/user.schema';

export type MidwifeDocument = Midwife & Document;

/**
 * Profil Sage-femme — Principalement associée au service Maternité.
 */
@Schema({ timestamps: true })
export class Midwife {
  @Prop({ type: Types.ObjectId, ref: User.name, required: true, unique: true })
  userId: Types.ObjectId;

  /**
   * Service d'affectation principale (généralement Maternité)
   * Référence une chaîne de caractères pour la flexibilité.
   */
  @Prop({ required: true, trim: true, default: 'Maternité' })
  service: string;

  /** Shift de travail */
  @Prop({ default: 'Matin (07h-15h)' })
  shift: string;

  /** Numéro d'enregistrement interne clinique */
  @Prop({ default: '', trim: true })
  registryId: string;

  /** Notes ou informations complémentaires */
  @Prop({ default: '' })
  notes: string;

  @Prop({ default: true })
  isActive: boolean;
}

export const MidwifeSchema = SchemaFactory.createForClass(Midwife);

MidwifeSchema.index({ service: 1 });
MidwifeSchema.index({ isActive: 1 });
