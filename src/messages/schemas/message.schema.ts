import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { User } from '../../users/schemas/user.schema';

export type MessageDocument = Message & Document;

export enum MessageType {
  TEXT = 'TEXT',
  IMAGE = 'IMAGE',
  DOCUMENT = 'DOCUMENT',
  PRESCRIPTION = 'PRESCRIPTION',
  RESULT = 'RESULT',
  AUDIO = 'AUDIO',
}

@Schema({ _id: false })
export class MessageAttachment {
  @Prop({ required: true })
  url: string;

  @Prop({ required: true })
  name: string;

  @Prop({ default: 'application/octet-stream' })
  fileType: string;

  @Prop({ default: 0 })
  sizeBytes?: number;
}

const MessageAttachmentSchema = SchemaFactory.createForClass(MessageAttachment);

@Schema({ timestamps: true })
export class Message {
  @Prop({ type: Types.ObjectId, ref: User.name, required: true })
  senderId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: User.name, default: null })
  recipientId?: Types.ObjectId;

  @Prop({ default: null })
  groupId?: string; // Ex: 'GARDE_URGENCES', 'LABO_RADIO', 'CORPS_MEDICAL'

  @Prop({ required: true, trim: true })
  content: string;

  @Prop({ type: String, enum: MessageType, default: MessageType.TEXT })
  messageType: MessageType;

  @Prop({ type: [MessageAttachmentSchema], default: [] })
  attachments: MessageAttachment[];

  @Prop({ default: false })
  isRead: boolean;

  @Prop({ type: Date, default: null })
  readAt?: Date;
}

export const MessageSchema = SchemaFactory.createForClass(Message);

MessageSchema.index({ senderId: 1, recipientId: 1 });
MessageSchema.index({ groupId: 1 });
MessageSchema.index({ createdAt: -1 });
