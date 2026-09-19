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
import { CallSignalDto, SendMessageDto } from './dto/message.dto';
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
}
