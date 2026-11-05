import { GoogleGenerativeAI, HarmBlockThreshold, HarmCategory } from '@google/generative-ai';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface AiGenerationResult {
  text: string;
  provider: 'gemini' | 'local';
}

@Injectable()
export class AiProviderService {
  private readonly logger = new Logger(AiProviderService.name);
  private readonly modelName = 'gemini-3.6-flash';
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
    const result = await this.generateResponseWithProvider(systemPrompt, context, userMessage, history);
    return result.text;
  }

  async generateResponseWithProvider(
    systemPrompt: string,
    context: string,
    userMessage: string,
    history: any[] = [],
  ): Promise<AiGenerationResult> {
    // Keep the timeout bounded so an unavailable provider does not stall the briefing.
    if (this.isConfigured && this.genAI) {
      let timeoutHandle: NodeJS.Timeout | undefined;
      try {
        const model = this.genAI.getGenerativeModel({
          model: this.modelName,
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 1000,
          },
        });

        const promptText = `${systemPrompt}\n\n[CONTEXTE CLINIQUEDONNÉES RÉELLES MONGO DB]\n${context}\n\n[DEMANDE]\n${userMessage}`;

        const callPromise = model.generateContent(promptText).then((res) => res.response.text());
        const timeoutPromise = new Promise<string>((_, reject) =>
          timeoutHandle = setTimeout(() => reject(new Error('Timeout Gemini API (5s)')), 5000),
        );

        const reply = await Promise.race([callPromise, timeoutPromise]);
        if (reply && reply.trim().length > 0) {
          return { text: reply.trim(), provider: 'gemini' };
        }
      } catch (err: any) {
        this.logger.warn(`Appel Gemini API non disponible ou clé invalide (${err?.message || err}). Utilisation du moteur de synthèse clinique local.`);
      } finally {
        if (timeoutHandle) clearTimeout(timeoutHandle);
      }
    }

    return {
      text: this.generateSmartFallbackResponse(systemPrompt, context, userMessage),
      provider: 'local',
    };
  }

  private generateSmartFallbackResponse(systemPrompt: string, context: string, userMessage: string): string {
    const lowerMsg = userMessage.toLowerCase();
    const lines = (context || '').split('\n').map((l) => l.trim()).filter((l) => l.length > 0);

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

    // 2. Synthèse patient complète (Dossier, Résumé, Récapitulatif PDF)
    if (
      lowerMsg.includes('résumé') ||
      lowerMsg.includes('resume') ||
      lowerMsg.includes('synthèse') ||
      lowerMsg.includes('synthese') ||
      lowerMsg.includes('recapitulatif') ||
      lowerMsg.includes('dossier')
    ) {
      const patientName = lines.find((l) => l.startsWith('Nom et Prénom'))?.split(':')[1]?.trim() || 'Patient';
      const dossierNum = lines.find((l) => l.startsWith('N° Dossier'))?.split(':')[1]?.trim() || 'N/A';
      const ageSex = lines.find((l) => l.startsWith('Date de Naissance')) || '';
      const allergies = lines.find((l) => l.startsWith('Allergies'))?.split(':')[1]?.trim() || 'Aucune';
      const chronic = lines.find((l) => l.startsWith('Antécédents'))?.split(':')[1]?.trim() || 'Aucun';
      const stay = lines.find((l) => l.startsWith('Service :'))?.split(':')[1]?.trim();
      const stayReason = lines.find((l) => l.startsWith("Motif d'admission"))?.split(':')[1]?.trim();

      const vitalsLines = lines.filter((l) => l.startsWith('•') && (l.includes('T°:') || l.includes('Tension')));
      const examLines = lines.filter((l) => /^\d+\.\s*\[.*\]\s*Examen:/.test(l));
      const consultLines = lines.filter((l) => /^\d+\.\s*\[.*\]\s*Motif:/.test(l));
      const alertLines = lines.filter((l) => l.startsWith('⚠️') || l.startsWith('🚨'));

      let summary = `### 📋 Synthèse Clinique & Antécédents
* **Patient** : ${patientName} (Dossier #${dossierNum})
* **Terrain & Facteurs de Risque** : ${chronic !== 'Aucune' && chronic !== 'Aucun' ? chronic : 'Pas d’antécédent lourd renseigné'}.
* **Allergies Signalées** : ${allergies !== 'Aucune' ? `⚠️ **${allergies}**` : 'Aucune allergie connue'}.
`;

      if (stay) {
        summary += `\n### 🏥 Séjour Hospitalier Actif
* **Département** : ${stay}
* **Motif d'Admission** : ${stayReason || 'Prise en charge spécialisée'}
`;
      }

      if (vitalsLines.length > 0) {
        summary += `\n### 🩺 Relevés des Constantes Récentes
${vitalsLines.slice(0, 3).join('\n')}
`;
      }

      if (consultLines.length > 0) {
        summary += `\n### 📝 Dernières Observations Médicales
${consultLines.slice(0, 2).join('\n')}
`;
      }

      if (examLines.length > 0) {
        summary += `\n### 🔬 Bilans & Clichés
${examLines.slice(0, 3).join('\n')}
`;
      }

      if (alertLines.length > 0) {
        summary += `\n### 🚨 Vigilance & Alertes
${alertLines.join('\n')}
`;
      } else {
        summary += `\n### 💡 Conduite à Tenir
* Poursuivre la surveillance rapprochée des paramètres vitaux.
* Respecter strictement les précautions relatives aux allergies mentionnées.`;
      }

      return summary;
    }

    // 3. Alertes
    const alertLines = lines.filter((l) => l.startsWith('🚨') || l.includes('⚠️') || l.toLowerCase().includes('alerte'));
    if (lowerMsg.includes('alerte') || lowerMsg.includes('urgence') || lowerMsg.includes('priorité')) {
      return `### ⚡ Alertes & Priorités Clés
${alertLines.length > 0 ? alertLines.join('\n') : '* Aucune alerte critique enregistrée pour vos patients.'}`;
    }

    // 4. Examens
    const examLines = lines.filter((l) => l.includes('Examen') || l.includes('Statut:') || l.includes('Bilan'));
    if (lowerMsg.includes('examen') || lowerMsg.includes('bilan') || lowerMsg.includes('analyse') || lowerMsg.includes('radio')) {
      return `### 🔬 Examens & Bilans Médicaux
${examLines.length > 0 ? examLines.join('\n') : '* Aucun examen en attente ou récent trouvé.'}`;
    }

    // 5. Hospitalisations
    const stayLines = lines.filter((l) => l.includes('Admission:') || l.includes('Service:') || l.includes('HOSPITALIS'));
    if (lowerMsg.includes('hospitalis') || lowerMsg.includes('chambre') || lowerMsg.includes('lit')) {
      return `### 🏥 Hospitalisations & Séjours
${stayLines.length > 0 ? stayLines.join('\n') : '* Aucune hospitalisation active en ce moment.'}`;
    }

    // 6. Synthèse par défaut
    return `### 🩺 Synthèse Clinique
${lines.slice(0, 15).join('\n')}`;
  }
}
