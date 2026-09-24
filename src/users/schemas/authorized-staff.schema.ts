import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { Role } from '../../common/enums/role.enum';
import { User } from './user.schema';

export type AuthorizedStaffDocument = AuthorizedStaff & Document;

@Schema({ timestamps: true })
export class AuthorizedStaff {
  @Prop({ required: true, unique: true, trim: true })
  cin: string; // Numéro de pièce / carte d'identité nationale

  @Prop({
    required: true,
    enum: [Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN, Role.ADMIN],
  })
  role: Role;

  @Prop({ required: true, trim: true })
  firstName: string;

  @Prop({ required: true, trim: true })
  lastName: string;

  @Prop({ default: '', lowercase: true, trim: true })
  email?: string;

  @Prop({ default: '' })
  phone?: string;

  // --- Champs spécifiques DOCTOR ---
  @Prop({ default: '' })
  specialty?: string; // Ex: Cardiologie, Pédiatrie

  @Prop({ default: '' })
  licenseNumber?: string; // Numéro d'ordre médical

  // --- Champs spécifiques NURSE / MIDWIFE ---
  @Prop({ default: '' })
  department?: string; // Service d'affectation (ex: Urgences, Maternité)

  @Prop({ default: '' })
  shift?: string; // Ex: Matin, Après-midi, Nuit

  // --- Champs spécifiques TECHNICIAN ---
  @Prop({ default: '' })
  technicalDepartment?: string; // Ex: Radiologie, Laboratoire

  @Prop({ default: '' })
  technicalSpecialty?: string; // Ex: Scanner, Biologie

  @Prop({ default: false })
  isRegistered: boolean;

  @Prop({ type: Types.ObjectId, ref: User.name, default: null })
  registeredUserId?: Types.ObjectId;
}

export const AuthorizedStaffSchema =
  SchemaFactory.createForClass(AuthorizedStaff);

AuthorizedStaffSchema.index({ role: 1 });
