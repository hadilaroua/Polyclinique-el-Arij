import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { User } from '../../users/schemas/user.schema';

export type ConversationDocument = Conversation & Document;

@Schema({ timestamps: true })
export class Conversation {
  @Prop({ type: [{ type: Types.ObjectId, ref: User.name }], default: [] })
  participants: Types.ObjectId[];

  @Prop({ default: null })
  groupId?: string;

  @Prop({ default: null })
  groupName?: string;

  @Prop({ default: '' })
  lastMessageContent: string;

  @Prop({ type: Date, default: Date.now })
  lastMessageAt: Date;

  @Prop({ type: Types.ObjectId, ref: User.name, default: null })
  lastMessageSenderId?: Types.ObjectId;

  @Prop({ type: Map, of: Number, default: {} })
  unreadCounts: Map<string, number>;
}

export const ConversationSchema = SchemaFactory.createForClass(Conversation);

ConversationSchema.index({ participants: 1 });
ConversationSchema.index({ groupId: 1 });
ConversationSchema.index({ lastMessageAt: -1 });
