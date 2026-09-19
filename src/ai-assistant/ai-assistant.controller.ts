import { Controller, Post, Get, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { AiAssistantService } from './ai-assistant.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('AI Assistant')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('ai-assistant')
export class AiAssistantController {
  constructor(private readonly aiAssistantService: AiAssistantService) {}

  @Get('daily-briefing')
  @ApiOperation({ summary: 'Générer le briefing quotidien avec l\'IA' })
  getDailyBriefing(@CurrentUser() user: any) {
    return this.aiAssistantService.getDailyBriefing(user);
  }

  @Post('patient-summary/:patientId')
  @ApiOperation({ summary: 'Générer le résumé intelligent d\'un patient' })
  getPatientSummary(
    @Param('patientId') patientId: string,
    @CurrentUser() user: any,
  ) {
    return this.aiAssistantService.getPatientSummary(patientId, user);
  }

  @Post('consultation-draft')
  @ApiOperation({ summary: 'Générer un brouillon de consultation à partir de notes' })
  generateConsultationDraft(
    @Body() body: { notes: string },
    @CurrentUser() user: any,
  ) {
    return this.aiAssistantService.generateConsultationDraft(body, user);
  }

  @Post('chat')
  @ApiOperation({ summary: 'Discuter avec l\'assistant IA' })
  chat(
    @Body() body: { sessionId?: string; message: string; patientId?: string },
    @CurrentUser() user: any,
  ) {
    return this.aiAssistantService.chat(body.sessionId, body.message, body.patientId, user);
  }
}
