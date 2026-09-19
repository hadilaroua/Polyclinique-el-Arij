import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../users/schemas/user.schema';
import { CallSignalDto, SendMessageDto } from './dto/message.dto';
import { Conversation, ConversationDocument } from './schemas/conversation.schema';
import { Message, MessageDocument, MessageType } from './schemas/message.schema';

const USER_POP = 'firstName lastName role avatarUrl email cin';

@Injectable()
export class MessagesService {
  constructor(
    @InjectModel(Message.name) private messageModel: Model<MessageDocument>,
    @InjectModel(Conversation.name) private conversationModel: Model<ConversationDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
  ) {}

  /**
   * Envoyer un message (1-à-1 ou Groupe)
   */
  async sendMessage(senderId: string, dto: SendMessageDto): Promise<MessageDocument> {
    if (!dto.recipientId && !dto.groupId) {
      throw new BadRequestException('Veuillez spécifier un destinataire ou un groupe.');
    }

    const senderObjId = new Types.ObjectId(senderId);
    const recipientObjId = dto.recipientId && Types.ObjectId.isValid(dto.recipientId)
      ? new Types.ObjectId(dto.recipientId)
      : null;

    const message = new this.messageModel({
      senderId: senderObjId,
      recipientId: recipientObjId,
      groupId: dto.groupId || null,
      content: dto.content,
      messageType: dto.messageType || MessageType.TEXT,
      attachments: dto.attachments || [],
      isRead: false,
    });

    const saved = await message.save();

    // Mise à jour de la conversation
    if (recipientObjId) {
      let conv = await this.conversationModel.findOne({
        groupId: null,
        participants: { $all: [senderObjId, recipientObjId] },
      });

      if (!conv) {
        conv = new this.conversationModel({
          participants: [senderObjId, recipientObjId],
          groupId: null,
          unreadCounts: new Map(),
        });
      }

      conv.lastMessageContent = dto.content;
      conv.lastMessageAt = new Date();
      conv.lastMessageSenderId = senderObjId;

      const currentUnread = conv.unreadCounts.get(recipientObjId.toString()) || 0;
      conv.unreadCounts.set(recipientObjId.toString(), currentUnread + 1);

      await conv.save();
    } else if (dto.groupId) {
      let groupConv = await this.conversationModel.findOne({ groupId: dto.groupId });
      if (!groupConv) {
        groupConv = new this.conversationModel({
          groupId: dto.groupId,
          groupName: this.getGroupName(dto.groupId),
          lastMessageContent: dto.content,
          lastMessageAt: new Date(),
          lastMessageSenderId: senderObjId,
          unreadCounts: new Map(),
        });
      } else {
        groupConv.lastMessageContent = dto.content;
        groupConv.lastMessageAt = new Date();
        groupConv.lastMessageSenderId = senderObjId;
      }
      await groupConv.save();
    }

    return saved.populate([
      { path: 'senderId', select: USER_POP },
      { path: 'recipientId', select: USER_POP },
    ]);
  }

  /**
   * Lister toutes les conversations d'un utilisateur
   */
  async getConversations(userId: string) {
    const userObjId = new Types.ObjectId(userId);

    // Récupérer toutes les personnes avec qui l'utilisateur peut converser (tous les employés)
    const staffList = await this.userModel
      .find({ _id: { $ne: userObjId } })
      .select(USER_POP)
      .exec();

    // Récupérer les conversations existantes
    const conversations = await this.conversationModel
      .find({
        $or: [{ participants: userObjId }, { groupId: { $ne: null } }],
      })
      .populate('participants', USER_POP)
      .populate('lastMessageSenderId', USER_POP)
      .sort({ lastMessageAt: -1 })
      .exec();

    return {
      staffList,
      conversations,
      groups: [
        { id: 'GARDE_URGENCES', name: '🚨 Garde & Urgences Clinique', description: 'Canal d\'urgence pour l\'équipe de garde' },
        { id: 'LABO_RADIO', name: '🩻 Plateau Technique & Labo', description: 'Demandes de résultats et bilans' },
        { id: 'CORPS_MEDICAL', name: '🩺 Corps Médical & Soignants', description: 'Discussions cliniques et avis médicaux' },
      ],
    };
  }

  /**
   * Historique de discussion entre 2 utilisateurs ou dans un groupe
   */
  async getHistory(userId: string, targetId: string, isGroup = false) {
    const userObjId = new Types.ObjectId(userId);

    if (isGroup) {
      return this.messageModel
        .find({ groupId: targetId })
        .populate('senderId', USER_POP)
        .sort({ createdAt: 1 })
        .limit(100)
        .exec();
    }

    if (!Types.ObjectId.isValid(targetId)) {
      throw new BadRequestException('ID destinataire invalide');
    }

    const targetObjId = new Types.ObjectId(targetId);

    // Marquer les messages reçus comme lus
    await this.messageModel.updateMany(
      { senderId: targetObjId, recipientId: userObjId, isRead: false },
      { $set: { isRead: true, readAt: new Date() } },
    );

    // Remettre le compteur de non lus à zéro dans la conversation
    const conv = await this.conversationModel.findOne({
      participants: { $all: [userObjId, targetObjId] },
    });
    if (conv) {
      conv.unreadCounts.set(userObjId.toString(), 0);
      await conv.save();
    }

    return this.messageModel
      .find({
        $or: [
          { senderId: userObjId, recipientId: targetObjId },
          { senderId: targetObjId, recipientId: userObjId },
        ],
      })
      .populate('senderId', USER_POP)
      .populate('recipientId', USER_POP)
      .sort({ createdAt: 1 })
      .limit(100)
      .exec();
  }

  /**
   * Signalisation d'appels voix/vidéo (Simulé)
   */
  async handleCallSignal(senderId: string, dto: CallSignalDto) {
    const sender = await this.userModel.findById(senderId).select(USER_POP).exec();
    const target = await this.userModel.findById(dto.targetUserId).select(USER_POP).exec();

    if (!sender || !target) throw new NotFoundException('Utilisateur introuvable');

    return {
      success: true,
      action: dto.action,
      callType: dto.callType,
      sender,
      target,
      timestamp: new Date().toISOString(),
      roomChannelId: `call_${[senderId, dto.targetUserId].sort().join('_')}`,
    };
  }

  private getGroupName(groupId: string): string {
    switch (groupId) {
      case 'GARDE_URGENCES':
        return '🚨 Garde & Urgences Clinique';
      case 'LABO_RADIO':
        return '🩻 Plateau Technique & Labo';
      case 'CORPS_MEDICAL':
        return '🩺 Corps Médical & Soignants';
      default:
        return 'Groupe de Discussion';
    }
  }
}
