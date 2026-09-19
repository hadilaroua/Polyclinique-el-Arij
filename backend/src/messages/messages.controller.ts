import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { ArchiveConversationDto, BlockUserDto, CallSignalDto, CreateGroupDto, SendMessageDto } from './dto/message.dto';
import { MessagesService } from './messages.service';

@ApiTags('Messagerie Staff')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('messages')
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Post('send')
  @Roles(Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE, Role.ADMIN)
  @ApiOperation({ summary: 'Envoyer un message ou un fichier (1-à-1 ou Groupe)' })
  sendMessage(
    @CurrentUser('sub') userId: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.messagesService.sendMessage(userId, dto);
  }

  @Get('conversations')
  @Roles(Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE, Role.ADMIN)
  @ApiOperation({ summary: 'Lister les conversations actives et les contacts staff' })
  getConversations(@CurrentUser('sub') userId: string) {
    return this.messagesService.getConversations(userId);
  }

  @Get('history/:targetId')
  @Roles(Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE, Role.ADMIN)
  @ApiOperation({ summary: 'Récupérer l\'historique des messages d\'une discussion' })
  @ApiQuery({ name: 'isGroup', required: false, type: Boolean })
  getHistory(
    @CurrentUser('sub') userId: string,
    @Param('targetId') targetId: string,
    @Query('isGroup') isGroup?: string,
  ) {
    const isGroupBool = isGroup === 'true';
    return this.messagesService.getHistory(userId, targetId, isGroupBool);
  }

  @Post('call/signal')
  @Roles(Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE, Role.ADMIN)
  @ApiOperation({ summary: 'Signalisation d\'appels audio et vidéo' })
  handleCallSignal(
    @CurrentUser('sub') userId: string,
    @Body() dto: CallSignalDto,
  ) {
    return this.messagesService.handleCallSignal(userId, dto);
  }

  @Get('call/pending')
  @Roles(Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE, Role.ADMIN)
  @ApiOperation({ summary: 'Vérifier s\'il y a un appel entrant en attente' })
  getPendingCall(@CurrentUser('sub') userId: string) {
    return this.messagesService.getPendingCall(userId);
  }


  @Post('groups/create')
  @Roles(Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE, Role.ADMIN)
  @ApiOperation({ summary: 'Créer un groupe de discussion personnalisé' })
  createCustomGroup(
    @CurrentUser('sub') userId: string,
    @Body() dto: CreateGroupDto,
  ) {
    return this.messagesService.createCustomGroup(userId, dto);
  }

  @Post('groups/:groupId/leave')
  @Roles(Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE, Role.ADMIN)
  @ApiOperation({ summary: 'Quitter un groupe de discussion' })
  leaveGroup(
    @CurrentUser('sub') userId: string,
    @Param('groupId') groupId: string,
  ) {
    return this.messagesService.leaveGroup(userId, groupId);
  }

  @Post('users/block')
  @Roles(Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE, Role.ADMIN)
  @ApiOperation({ summary: 'Bloquer ou débloquer un contact' })
  blockUser(
    @CurrentUser('sub') userId: string,
    @Body() dto: BlockUserDto,
  ) {
    return this.messagesService.blockUser(userId, dto.targetUserId);
  }

  @Post('conversations/archive')
  @Roles(Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE, Role.ADMIN)
  @ApiOperation({ summary: 'Archiver ou désarchiver une discussion' })
  archiveConversation(
    @CurrentUser('sub') userId: string,
    @Body() dto: ArchiveConversationDto,
  ) {
    return this.messagesService.archiveConversation(userId, dto.targetId);
  }
}
