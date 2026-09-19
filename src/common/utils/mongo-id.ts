import { BadRequestException } from '@nestjs/common';
import { Types } from 'mongoose';

export function isMongoObjectId(id: string): boolean {
  return Types.ObjectId.isValid(id) && new Types.ObjectId(id).toString() === id;
}

export function assertMongoObjectId(id: string, label = 'identifiant'): void {
  if (!isMongoObjectId(id)) {
    throw new BadRequestException(
      `Identifiant invalide : « ${id} ». Un ${label} MongoDB doit contenir 24 caractères hexadécimaux.`,
    );
  }
}
