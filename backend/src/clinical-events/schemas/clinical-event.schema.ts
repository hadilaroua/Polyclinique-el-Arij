import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type ClinicalEventDocument = ClinicalEvent & Document;

@Schema({ timestamps: true })
export class ClinicalEvent {
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'Patient', required: true })
  patientId: MongooseSchema.Types.ObjectId;

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true })
  doctorId: MongooseSchema.Types.ObjectId;

  @Prop({ required: true })
  roomId: string; // e.g. "Bloc opératoire 1", "Salle maternité 2"

  @Prop({ type: String, required: true, enum: ['SURGERY', 'CESAREAN', 'DELIVERY', 'PROCEDURE', 'OTHER'], default: 'PROCEDURE' })
  procedureType: string;

  @Prop({ required: true })
  procedureTitle: string; // e.g. "Césarienne", "Chirurgie cardiaque"

  @Prop({ required: true })
  date: string; // YYYY-MM-DD

  @Prop({ required: true })
  startTime: string; // HH:mm

  @Prop({ required: true })
  endTime: string; // HH:mm

  @Prop({ type: String, required: true, enum: ['SCHEDULED', 'COMPLETED', 'CANCELLED'], default: 'SCHEDULED' })
  status: string;

  @Prop({ default: '' })
  notes: string;

  @Prop({ type: [{ type: MongooseSchema.Types.ObjectId, ref: 'User' }], default: [] })
  assignedStaffIds: MongooseSchema.Types.ObjectId[];

  @Prop({ default: '' })
  googleCalendarEventId: string;
}

export const ClinicalEventSchema = SchemaFactory.createForClass(ClinicalEvent);
