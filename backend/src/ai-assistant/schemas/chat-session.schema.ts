import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export enum ChatMessageRole {
  USER = 'user',
  MODEL = 'model',
  SYSTEM = 'system',
}

@Schema({ timestamps: true })
export class ChatMessage {
  @Prop({ required: true, enum: ChatMessageRole })
  role: ChatMessageRole;

  @Prop({ required: true })
  content: string;

  @Prop({ type: Date, default: Date.now })
  timestamp: Date;
}

export type ChatSessionDocument = ChatSession & Document;

@Schema({ timestamps: true })
export class ChatSession {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  userId: Types.ObjectId;

  @Prop({ type: String, required: true })
  title: string;

  @Prop({ type: [{ role: String, content: String, timestamp: Date }], default: [] })
  messages: ChatMessage[];
}

export const ChatSessionSchema = SchemaFactory.createForClass(ChatSession);
