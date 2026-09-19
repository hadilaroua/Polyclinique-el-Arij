import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { CreateNotificationDto } from './dto/notification.dto';
import {
  Notification,
  NotificationDocument,
} from './schemas/notification.schema';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectModel(Notification.name)
    private notifModel: Model<NotificationDocument>,
  ) {}

  async create(dto: CreateNotificationDto): Promise<NotificationDocument> {
    const notif = new this.notifModel({
      ...dto,
      recipientUserId: new Types.ObjectId(dto.recipientUserId),
    });
    return notif.save();
  }

  async findAllForUser(userId: string): Promise<NotificationDocument[]> {
    return this.notifModel
      .find({ recipientUserId: new Types.ObjectId(userId) })
      .sort({ createdAt: -1 })
      .limit(50)
      .exec();
  }

  async markAsRead(id: string, userId: string): Promise<NotificationDocument> {
    const notif = await this.notifModel.findOneAndUpdate(
      {
        _id: new Types.ObjectId(id),
        recipientUserId: new Types.ObjectId(userId),
      },
      { isRead: true },
      { new: true },
    );

    if (!notif) {
      throw new NotFoundException('Notification introuvable');
    }
    return notif;
  }

  async markAllAsRead(userId: string): Promise<{ modifiedCount: number }> {
    const res = await this.notifModel.updateMany(
      { recipientUserId: new Types.ObjectId(userId), isRead: false },
      { isRead: true },
    );
    return { modifiedCount: res.modifiedCount };
  }

  async getUnreadCount(userId: string): Promise<{ unreadCount: number }> {
    const count = await this.notifModel.countDocuments({
      recipientUserId: new Types.ObjectId(userId),
      isRead: false,
    });
    return { unreadCount: count };
  }
}
