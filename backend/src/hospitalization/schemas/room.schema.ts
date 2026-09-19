import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type RoomDocument = Room & Document;

@Schema({ timestamps: true })
export class Room {
  @Prop({ required: true, trim: true })
  number: string;

  @Prop({ required: true, trim: true })
  service: string; // Ex: Maternité, Hospitalisation, Réanimation

  @Prop({ default: 1 })
  capacity: number;

  @Prop({ default: '', trim: true })
  floor: string;

  @Prop({ default: '', trim: true })
  description: string;

  @Prop({ default: 'STANDARD', trim: true })
  roomType: string;

  @Prop({ default: true })
  isActive: boolean;
}

export const RoomSchema = SchemaFactory.createForClass(Room);
RoomSchema.index({ service: 1 });
RoomSchema.index({ isActive: 1 });
