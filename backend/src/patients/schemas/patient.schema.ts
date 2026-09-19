import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { User } from '../../users/schemas/user.schema';

export type PatientDocument = Patient & Document;

@Schema({ _id: false })
export class EmergencyContact {
  @Prop({ default: '' })
  name: string;

  @Prop({ default: '' })
  phone: string;

  @Prop({ default: '' })
  relation: string;
}

export const EmergencyContactSchema =
  SchemaFactory.createForClass(EmergencyContact);

/**
 * Patient — Entité métier V1
 *
 * En V1, le patient n'a PAS de compte utilisateur.
 * Il est géré uniquement par l'administration (Admin) et les professionnels.
 * userId est optionnel et réservé à la V2 (application patient future).
 */
@Schema({ timestamps: true })
export class Patient {
  // --- Identité du patient (données directes, plus de dépendance User obligatoire) ---
  @Prop({ required: true, trim: true })
  firstName: string;

  @Prop({ required: true, trim: true })
  lastName: string;

  @Prop({ required: true, unique: true, trim: true, uppercase: true })
  cin: string;

  @Prop({ required: true, unique: true, uppercase: true, trim: true })
  dossierNumber: string;

  @Prop({ required: true })
  dateOfBirth: string; // Format ISO: YYYY-MM-DD

  @Prop({ default: 'Non spécifié' })
  gender: string;

  @Prop({ default: '' })
  phone: string;

  @Prop({ default: '' })
  address: string;

  // --- Données médicales de base ---
  @Prop({ default: 'Inconnu' })
  bloodType: string;

  @Prop({ type: [String], default: [] })
  allergies: string[];

  @Prop({ type: [String], default: [] })
  chronicDiseases: string[];

  // --- Contact d'urgence ---
  @Prop({ type: EmergencyContactSchema, default: () => ({}) })
  emergencyContact: EmergencyContact;

  // --- QR Code (conservé pour usage interne du personnel) ---
  @Prop({ unique: true, sparse: true })
  qrCodeToken?: string;

  @Prop({ default: '' })
  qrCodeImage: string;

  // --- Équipe Soignante & Affectation Clinique ---
  @Prop({ type: Types.ObjectId, ref: User.name, required: false })
  attendingDoctorId?: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: User.name, required: false })
  assignedMidwifeId?: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: User.name, required: false })
  assignedNurseId?: Types.ObjectId;

  @Prop({ default: 'MATERNITE', trim: true })
  department: string;

  @Prop({ default: '', trim: true })
  careTeamNotes: string;

  // --- Statut ---
  @Prop({ default: true })
  isActive: boolean;

  /**
   * userId est OPTIONNEL en V1.
   * Sera rempli en V2 lorsque le patient créera son compte.
   */
  @Prop({ type: Types.ObjectId, ref: User.name, required: false })
  userId?: Types.ObjectId;
}

export const PatientSchema = SchemaFactory.createForClass(Patient);

PatientSchema.index({ lastName: 1, firstName: 1 });
PatientSchema.index({ cin: 1 });
PatientSchema.index({ dossierNumber: 1 });
PatientSchema.index({ isActive: 1 });
PatientSchema.index({ department: 1 });
PatientSchema.index({ attendingDoctorId: 1 });
PatientSchema.index({ assignedMidwifeId: 1 });
PatientSchema.index({ assignedNurseId: 1 });
