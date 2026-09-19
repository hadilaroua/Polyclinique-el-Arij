import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { ChatSession, ChatSessionDocument } from './schemas/chat-session.schema';
import { AiProviderService } from './services/ai-provider.service';
import { AiContextBuilderService } from './services/ai-context-builder.service';
import { DailyBriefingService } from './services/daily-briefing.service';

@Injectable()
export class AiAssistantService {
  constructor(
    @InjectModel(ChatSession.name) private chatSessionModel: Model<ChatSessionDocument>,
    private aiProvider: AiProviderService,
    private contextBuilder: AiContextBuilderService,
    private dailyBriefing: DailyBriefingService,
  ) {}

  async getDailyBriefing(user: any) {
    return this.dailyBriefing.generateBriefing(user);
  }

  async getPatientSummary(patientId: string, user: any) {
    const context = await this.contextBuilder.buildPatientContext(patientId, user);
    if (context.startsWith('ACCÈS REFUSÉ') || context.startsWith('Patient introuvable')) {
      throw new BadRequestException(context);
    }

    const systemPrompt = `Tu es Arij Assistant, un assistant médical intelligent. Ton but est de résumer de manière structurée et concise le dossier de ce patient. N'invente AUCUNE information. Utilise le format Markdown. Ajoute des alertes si nécessaire. Reste neutre et factuel.`;
    
    const summary = await this.aiProvider.generateResponse(systemPrompt, context, 'Fais-moi un résumé complet et structuré de ce patient.');
    return { summary };
  }

  async generateConsultationDraft(data: any, user: any) {
    const systemPrompt = `Tu es Arij Assistant. Structure les notes brutes du médecin en une consultation médicale formelle (Motif, Observations, Antécédents, Examens, Plan). Garde le ton professionnel. N'invente pas de diagnostic non mentionné.`;
    const draft = await this.aiProvider.generateResponse(systemPrompt, '', `Notes brutes : ${data.notes}`);
    return { draft };
  }

  private getHonorific(user: any): string {
    const gender = (user?.gender || user?.sexe || '').toString().toUpperCase();
    const role = (user?.role || '').toString().toUpperCase();
    if (gender === 'F' || gender === 'FEMALE' || gender === 'WOMAN' || gender === 'FEMININ' || role === 'MIDWIFE') {
      return 'Mme';
    }
    return 'M.';
  }

  async chat(sessionId: string | undefined, message: string, patientId: string | undefined, user: any) {
    const userId = user._id || user.id || user.sub;
    let session;
    if (sessionId) {
      session = await this.chatSessionModel.findOne({ _id: sessionId, userId });
      if (!session) throw new NotFoundException('Session introuvable');
    } else {
      session = await this.chatSessionModel.create({
        userId,
        title: message.substring(0, 30) + '...',
      });
    }

    // Ajouter le message utilisateur
    session.messages.push({ role: 'user', content: message, timestamp: new Date() } as any);
    await session.save();

    const honorific = this.getHonorific(user);
    const userName = (user?.lastName ? `${user.lastName}` : (user?.firstName || '')).trim();
    const fullSalutation = userName ? `${honorific} ${userName}` : honorific;

    // Détection de salutation simple
    const cleanMsg = message.trim().toLowerCase();
    const isGreeting = /^(bonjour|hello|salut|bonsoir|coucou|hi|hey|bonjour\s*assistant)$/i.test(cleanMsg) || cleanMsg.startsWith('bonjour') && cleanMsg.length < 15;

    let aiResponse = '';

    if (isGreeting && !patientId) {
      aiResponse = `Bonjour ${fullSalutation}, comment puis-je vous aider aujourd'hui ?\n\nVous pouvez me poser directement votre question ou choisir l'une des options rapides ci-dessus.`;
    } else {
      // Construire le contexte (spécifique au patient ou général real-time)
      let context = '';
      if (patientId) {
        context = await this.contextBuilder.buildPatientContext(patientId, user);
      } else {
        context = await this.contextBuilder.buildGeneralClinicalContext(user);
      }

      const systemPrompt = `Tu es Arij Assistant, l'assistant virtuel médical intelligent de la Polyclinique Arij. L'utilisateur connecté est ${fullSalutation} (Rôle: ${user.role}).

DIRECTIVES STRICTES DE STRUCTURE ET DE RÉPONSE :
1. Organise TOUJOURS ta réponse de manière très claire, professionnelle et structurée avec des titres H3 Markdown ('### Title').
2. Inclus systématiquement les sections suivantes lorsque pertinent :
   - **### 📊 Synthèse Clinique** : Résumé exécutif en 2-3 lignes.
   - **### 📋 Données & Faits Cliniques** : Liste à puces aérée avec du gras (**Nom Patient**, **Statut**, **Valeur**) extraite de la base de données.
   - **### 💡 Recommandations & Conseils** : Recommandations pratiques, astuces de surveillance, précautions ou pistes diagnostiques adaptées au rôle du soignant.
3. Pour chaque alerte ou bilan, mentionne OBLIGATOIREMENT le Nom et Prénom du patient concerné (ex: Patient: Ali Mansour).
4. N'AFFICHE JAMAIS d'IDs techniques MongoDB (ex: 6aa1...), d'entêtes système brutes ou de 'undefined'.
5. Reste extrêmement neutre, concis et directement utile pour le personnel soignant.`;

      aiResponse = await this.aiProvider.generateResponse(
        systemPrompt,
        context,
        message,
        session.messages.slice(0, -1)
      );
    }

    // Ajouter la réponse du modèle
    session.messages.push({ role: 'model', content: aiResponse, timestamp: new Date() } as any);
    await session.save();

    return {
      sessionId: session._id,
      response: aiResponse,
      reply: aiResponse,
    };
  }
}

