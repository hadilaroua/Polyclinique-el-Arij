import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { User } from '../../users/schemas/user.schema';

export type NurseDocument = Nurse & Document;

@Schema({ timestamps: true })
export class Nurse {
  @Prop({ type: Types.ObjectId, ref: User.name, required: true, unique: true })
  userId: Types.ObjectId;

  @Prop({ required: true, trim: true })
  department: string;

  @Prop({ default: 'Matin (07h-15h)' })
  shift: string;

  @Prop({ type: [String], default: [] })
  assignedRooms: string[];

  @Prop({ default: true })
  isAvailable: boolean;
}

export const NurseSchema = SchemaFactory.createForClass(Nurse);

NurseSchema.index({ department: 1 });

