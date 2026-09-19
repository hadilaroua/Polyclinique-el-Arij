import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { Room } from './room.schema';

export type BedDocument = Bed & Document;

export enum BedStatus {
  AVAILABLE = 'AVAILABLE',
  OCCUPIED = 'OCCUPIED',
  MAINTENANCE = 'MAINTENANCE',
}

@Schema({ timestamps: true })
export class Bed {
  @Prop({ required: true, trim: true })
  number: string;

  @Prop({ type: Types.ObjectId, ref: Room.name, required: true })
  roomId: Types.ObjectId;

  @Prop({ required: true, enum: BedStatus, default: BedStatus.AVAILABLE })
  status: BedStatus;

  @Prop({ default: '', trim: true })
  notes: string;
}

export const BedSchema = SchemaFactory.createForClass(Bed);
BedSchema.index({ roomId: 1 });
BedSchema.index({ status: 1 });
