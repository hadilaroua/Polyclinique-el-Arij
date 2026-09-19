import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type ClinicInfoDocument = ClinicInfo & Document;

@Schema({ _id: false })
export class ClinicDepartment {
  @Prop({ required: true })
  name: string;

  @Prop({ default: '' })
  description: string;

  @Prop({ default: '' })
  headDoctor?: string;

  @Prop({ default: 'medical-services' })
  icon?: string;
}

export const ClinicDepartmentSchema =
  SchemaFactory.createForClass(ClinicDepartment);

@Schema({ timestamps: true })
export class ClinicInfo {
  @Prop({ required: true, default: 'Polyclinique Arij Djerba' })
  name: string;

  @Prop({
    default: 'Excellence médicale et assistance continue au cœur de Djerba',
  })
  slogan: string;

  @Prop({ required: true, default: 'Avenue Habib Bourguiba, Midoun, Djerba 4116' })
  address: string;

  @Prop({ required: true, default: '+216 75 730 000' })
  phonePrimary: string;

  @Prop({ required: true, default: '+216 75 730 112' })
  emergencyPhone: string;

  @Prop({ required: true, default: 'contact@polyclinique-arij.tn' })
  email: string;

  @Prop({ default: 'https://polyclinique-arij.tn' })
  website: string;

  @Prop({ default: 'Service d’urgences 24h/24 et 7j/7 — Consultations 08h-20h' })
  openingHours: string;

  @Prop({ default: 33.8075 })
  latitude: number;

  @Prop({ default: 10.9922 })
  longitude: number;

  @Prop({ type: [ClinicDepartmentSchema], default: [] })
  departments: ClinicDepartment[];

  @Prop({ type: [String], default: [] })
  services: string[];

  @Prop({ type: [String], default: [] })
  practicalInfo: string[];
}

export const ClinicInfoSchema = SchemaFactory.createForClass(ClinicInfo);
