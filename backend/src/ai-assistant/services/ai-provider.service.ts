import { GoogleGenerativeAI, HarmBlockThreshold, HarmCategory } from '@google/generative-ai';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AiProviderService {
  private readonly logger = new Logger(AiProviderService.name);
  private genAI?: GoogleGenerativeAI;
  private isConfigured = false;

  constructor(private configService: ConfigService) {
    const apiKey = this.configService.get<string>('GEMINI_API_KEY');
    if (apiKey && apiKey.trim().length > 5) {
      try {
        this.genAI = new GoogleGenerativeAI(apiKey.trim());
        this.isConfigured = true;
        this.logger.log('Intégration Google Gemini API activée.');
      } catch (e) {
        this.logger.error('Erreur d\'initialisation du SDK Gemini:', e);
      }
    } else {
      this.logger.warn('GEMINI_API_KEY non configurée dans .env. Mode IA clinique local (Smart Fallback) actif.');
    }
  }

  /**
   * Envoie un prompt au modèle LLM ou génère une réponse clinique intelligente structurée
   */
  async generateResponse(
    systemPrompt: string,
    context: string,
    userMessage: string,
    history: any[] = [],
  ): Promise<string> {
    if (this.isConfigured && this.genAI) {
      try {
        const model = this.genAI.getGenerativeModel({
          model: 'gemini-3.6-flash',
          safetySettings: [
            {
              category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
              threshold: HarmBlockThreshold.BLOCK_NONE,
            },
            {
              category: HarmCategory.HARM_CATEGORY_HARASSMENT,
              threshold: HarmBlockThreshold.BLOCK_NONE,
            },
            {
              category: HarmCategory.HARM_CATEGORY_HATE_SPEECH,
              threshold: HarmBlockThreshold.BLOCK_NONE,
            },
            {
              category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
              threshold: HarmBlockThreshold.BLOCK_NONE,
            },
          ],
          systemInstruction: systemPrompt,
        });

        const geminiHistory = history.map((msg) => ({
          role: msg.role === 'user' ? 'user' : 'model',
          parts: [{ text: msg.content }],
        }));

        const contextualMessage = context
          ? `[CONTEXTE MÉDICAL RESTREINT - À UTILISER POUR TA RÉPONSE]\n${context}\n\n[QUESTION DE L'UTILISATEUR]\n${userMessage}`
          : userMessage;

        const chat = model.startChat({
          history: geminiHistory,
        });

        const result = await chat.sendMessage(contextualMessage);
        const response = await result.response;
        const text = response.text();
        if (text && text.trim().length > 0) {
          return text;
        }
      } catch (error) {
        this.logger.error('Erreur API Gemini (Bascule automatique en mode Smart Fallback):', error);
      }
    }

    // --- Mode IA Clinique Intelligente (Fallback local structuré) ---
    return this.generateSmartFallbackResponse(systemPrompt, context, userMessage);
  }

  private generateSmartFallbackResponse(systemPrompt: string, context: string, userMessage: string): string {
    const lowerMsg = userMessage.toLowerCase();

    // Extraire les lignes informatives du contexte
    const lines = (context || '').split('\n').map(l => l.trim()).filter(l => l.length > 0);

    // 1. Brouillon de consultation
    if (lowerMsg.includes('brouillon') || lowerMsg.includes('compte-rendu') || lowerMsg.includes('notes brutes')) {
      const cleanNotes = userMessage.replace(/notes brutes\s*:\s*/i, '').replace(/générer un compte-rendu.*/i, '').trim();
      return `### 📋 Brouillon de Consultation Médicale

#### 1. Motif & Observations
${cleanNotes.length > 0 ? cleanNotes : 'Consultation clinique et évaluation des symptômes.'}

#### 2. Diagnostic Présomptif & Évaluation
* Diagnostic à confirmer selon corrélation clinique et bilans.

#### 3. Plan de Prise en Charge
* 💊 Prescriptions adaptées au tableau clinique.
* 🔬 Surveillance continue des constantes.`;
    }

    // Si nous avons des données réelles dans le contexte, présentons-les de manière lisible
    const alertLines = lines.filter(l => l.startsWith('🚨') || l.includes('⚠️') || l.toLowerCase().includes('alerte'));
    const examLines = lines.filter(l => l.includes('Examen') || l.includes('Statut:') || l.includes('Bilan'));
    const stayLines = lines.filter(l => l.includes('Admission:') || l.includes('Service:') || l.includes('HOSPITALIS'));
    const patientLines = lines.filter(l => l.includes('Patient:') || l.includes('Dossier:'));

    // 2. Alertes
    if (lowerMsg.includes('alerte') || lowerMsg.includes('urgence') || lowerMsg.includes('priorité')) {
      return `### ⚡ Alertes & Priorités Clés
${alertLines.length > 0 ? alertLines.join('\n') : '* Aucune alerte critique enregistrée pour vos patients.'}`;
    }

    // 3. Examens
    if (lowerMsg.includes('examen') || lowerMsg.includes('bilan') || lowerMsg.includes('analyse') || lowerMsg.includes('radio')) {
      return `### 🔬 Examens & Bilans Médicaux
${examLines.length > 0 ? examLines.join('\n') : '* Aucun examen en attente ou récent trouvé.'}`;
    }

    // 4. Hospitalisations
    if (lowerMsg.includes('hospitalis') || lowerMsg.includes('chambre') || lowerMsg.includes('lit')) {
      return `### 🏥 Hospitalisations & Séjours
${stayLines.length > 0 ? stayLines.join('\n') : '* Aucune hospitalisation active en ce moment.'}`;
    }

    // 5. Synthèse générale
    return `### 🩺 Synthèse Clinique
${lines.slice(0, 15).join('\n')}`;
  }
}
