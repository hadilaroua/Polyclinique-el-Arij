import { Body, Controller, Get, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Public } from '../common/decorators/public.decorator';
import { ChatbotService } from './chatbot.service';
import { ChatMessageDto } from './dto/chat-message.dto';

@ApiTags('Assistant Intelligent / Chatbot')
@Controller('chatbot')
export class ChatbotController {
  constructor(private readonly chatbotService: ChatbotService) {}

  @Public()
  @Post('ask')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Poser une question à l’assistant intelligent sur la clinique (horaires, médecins, urgences, etc.)',
  })
  @ApiResponse({
    status: 200,
    description: 'Réponse générée par l’assistant avec éventuelle clause médicale',
  })
  ask(@Body() dto: ChatMessageDto) {
    return this.chatbotService.processQuestion(dto.message);
  }

  @Public()
  @Get('faq-topics')
  @ApiOperation({
    summary: 'Obtenir la liste des thèmes et questions fréquentes suggérées',
  })
  getFaqTopics() {
    return this.chatbotService.getSuggestedTopics();
  }
}
