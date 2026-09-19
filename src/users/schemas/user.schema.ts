import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { Role } from '../../common/enums/role.enum';

export type UserDocument = User & Document;

@Schema({ timestamps: true })
export class User {
  @Prop({ required: true, trim: true })
  firstName: string;

  @Prop({ required: true, trim: true })
  lastName: string;

  @Prop({ required: true, unique: true, lowercase: true, trim: true })
  email: string;

  @Prop({ required: true, select: false })
  password?: string;

  @Prop({ trim: true })
  phone?: string;

  @Prop({ trim: true, default: null })
  cin?: string;

  @Prop({ required: true, enum: Role, default: Role.PATIENT })
  role: Role;

  @Prop({ default: null })
  avatarUrl?: string;

  @Prop({ default: true })
  isActive: boolean;
}

export const UserSchema = SchemaFactory.createForClass(User);

UserSchema.index({ role: 1 });
UserSchema.index(
  { cin: 1 },
  { unique: true, partialFilterExpression: { cin: { $type: 'string' } } },
);
