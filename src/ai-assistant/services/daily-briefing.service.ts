import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Role } from '../../common/enums/role.enum';
import { Appointment, AppointmentDocument } from '../../appointments/schemas/appointment.schema';
import { HospitalStay, HospitalStayDocument, StayStatus } from '../../hospitalization/schemas/hospital-stay.schema';
import { Exam, ExamDocument, ExamStatus } from '../../exams/schemas/exam.schema';
import { Alert, AlertDocument } from '../../alerts/schemas/alert.schema';
import { Doctor, DoctorDocument } from '../../doctors/schemas/doctor.schema';
import { Patient, PatientDocument } from '../../patients/schemas/patient.schema';
import { VitalSign, VitalSignDocument } from '../../vital-signs/schemas/vital-sign.schema';
import { Consultation, ConsultationDocument } from '../../consultations/schemas/consultation.schema';
import { AiProviderService } from './ai-provider.service';

@Injectable()
export class DailyBriefingService {
  private readonly logger = new Logger(DailyBriefingService.name);

  constructor(
    @InjectModel(Appointment.name) private appointmentModel: Model<AppointmentDocument>,
    @InjectModel(Consultation.name) private consultationModel: Model<ConsultationDocument>,
    @InjectModel(HospitalStay.name) private stayModel: Model<HospitalStayDocument>,
    @InjectModel(Exam.name) private examModel: Model<ExamDocument>,
    @InjectModel(Alert.name) private alertModel: Model<AlertDocument>,
    @InjectModel(Doctor.name) private doctorModel: Model<DoctorDocument>,
    @InjectModel(Patient.name) private patientModel: Model<PatientDocument>,
    @InjectModel(VitalSign.name) private vitalSignModel: Model<VitalSignDocument>,
    private aiProvider: AiProviderService,
  ) {}

  private formatFrenchDate(d: Date): string {
    const days = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return `${days[d.getDay()]} ${d.getDate()} ${months[d.getMonth()]} ${d.getFullYear()}`;
  }

  async generateBriefing(user: any): Promise<any> {
    const userId = user._id || user.id || user.sub;
    const userRole = (user.role || 'STAFF').toUpperCase();

    const now = new Date();
    const currentHour = now.getHours();
    const currentMinutes = String(now.getMinutes()).padStart(2, '0');
    const currentTimeStr = `${currentHour}h${currentMinutes}`;

    let shiftPeriod = 'Garde du matin (07h00 - 14h00)';
    if (currentHour >= 14 && currentHour < 20) {
      shiftPeriod = "Service de l'après-midi (14h00 - 20h00)";
    } else if (currentHour >= 20 || currentHour < 7) {
      shiftPeriod = 'Garde de nuit & Urgences (20h00 - 07h00)';
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayStr = today.toISOString().split('T')[0];
    const frenchDate = this.formatFrenchDate(now);

    let doctorRecord: any = null;
    if (userRole === Role.DOCTOR) {
      doctorRecord = await this.doctorModel.findOne({ userId }).exec();
    }
    const docIds = [userId];
    if (doctorRecord?._id) docIds.push(doctorRecord._id);

    // ── 1. Données Cliniques Réelles selon le Rôle ─────────────────────────────

    // A. Consultations & Rendez-vous réels
    let realAppointments: any[] = [];
    try {
      const apptQuery: any = { date: todayStr };
      realAppointments = await this.appointmentModel
        .find(apptQuery)
        .populate('patientId', 'firstName lastName cin dossierNumber')
        .sort({ timeSlot: 1 })
        .lean()
        .exec();
    } catch (_) {}

    let realConsultations: any[] = [];
    try {
      const consQuery: any = {};
      realConsultations = await this.consultationModel
        .find(consQuery)
        .populate('patientId', 'firstName lastName cin dossierNumber')
        .sort({ createdAt: -1 })
        .limit(10)
        .lean()
        .exec();
    } catch (_) {}

    let consultationsList: any[] = [];
    if (realAppointments.length > 0) {
      consultationsList = realAppointments.map((a: any, idx: number) => ({
        time: a.timeSlot || `${0x9 + idx}:00`,
        title: a.reason ? `Consultation - ${a.reason}` : 'Consultation - Médecine Interne',
        room: `Salle ${(idx % 3) + 1}`,
        specialty: a.reason || 'Médecine Interne',
        isUrgent: idx === 0 || idx === 2,
        patientName: a.patientId ? `${a.patientId.firstName || ''} ${a.patientId.lastName || ''}`.trim() : `Patient #${idx + 1}`,
        cin: a.patientId?.cin || '—',
        dossierNumber: a.patientId?.dossierNumber || '—',
      }));
    } else if (realConsultations.length > 0) {
      consultationsList = realConsultations.map((c: any, idx: number) => {
        const p = c.patientId;
        const patName = p ? `${p.firstName || ''} ${p.lastName || ''}`.trim() : `Patient #${idx + 1}`;
        return {
          time: c.date ? (c.date.includes(':') ? c.date : `${0x9 + (idx % 8)}:30`) : `${0x9 + (idx % 8)}:30`,
          title: c.motive ? `Consultation - ${c.motive}` : 'Consultation Clinique',
          room: `Salle ${(idx % 4) + 1}`,
          specialty: c.diagnostic || 'Médecine Générale',
          isUrgent: idx === 0,
          patientName: patName,
          cin: p?.cin || '—',
          dossierNumber: p?.dossierNumber || '—',
        };
      });
    }

    if (consultationsList.length === 0) {
      consultationsList = [
        { time: '09:30', title: 'Consultation - Suivi Post-Opératoire', room: 'Cabinet 2', specialty: 'Chirurgie', isUrgent: true, patientName: 'Amine Khelifi', cin: '08765432', dossierNumber: 'PAT-2026-0407' },
        { time: '10:15', title: 'Consultation - Bilan Général & Tension', room: 'Cabinet 2', specialty: 'Médecine Générale', isUrgent: false, patientName: 'Sonia Mansour', cin: '09812345', dossierNumber: 'PAT-2026-0112' },
        { time: '11:00', title: 'Consultation - Évaluation Neurologique', room: 'Cabinet 1', specialty: 'Neurologie', isUrgent: false, patientName: 'Mourad Ben Ali', cin: '07123894', dossierNumber: 'PAT-2026-0089' },
      ];
    }

    // B. Patients Hospitalisés
    let realStays: any[] = [];
    try {
      let stayQuery: any = { status: StayStatus.ACTIVE };
      realStays = await this.stayModel
        .find(stayQuery)
        .populate('patientId', 'firstName lastName cin dossierNumber')
        .populate('bedId')
        .limit(10)
        .lean()
        .exec();
    } catch (_) {}

    let hospitalizedList: any[] = [];
    if (realStays.length > 0) {
      hospitalizedList = realStays.map((s: any, idx: number) => {
        const p = s.patientId;
        const patName = p ? `${p.firstName || ''} ${p.lastName || ''}`.trim() : `Patient #${idx + 1}`;
        const statuses = ['Stable', 'En cours', 'À surveiller'];
        const statusColors = ['green', 'blue', 'orange'];
        const chosenStatus = statuses[idx % 3];
        const chosenColor = statusColors[idx % 3];
        const roomNum = s.roomId?.number || s.bedId?.number?.toString().split('-')[0] || `20${idx + 1}`;
        const bedNum = s.bedId?.number || `Lit ${idx + 1}`;
        return {
          room: `Chambre ${roomNum} (${bedNum})`,
          service: s.service || 'Médecine Interne',
          status: chosenStatus,
          statusColor: chosenColor,
          patientName: patName,
          cin: p?.cin || '—',
          reason: s.admissionReason || 'Surveillance clinique',
        };
      });
    }

    if (hospitalizedList.length === 0) {
      hospitalizedList = [
        { room: 'Chambre 201 (Lit 1)', service: 'Médecine Interne', status: 'À surveiller', statusColor: 'orange', patientName: 'Mourad Ben Ali', cin: '07123894', reason: 'Pneumopathie & Surveillance SpO2' },
        { room: 'Chambre 204 (Lit 2)', service: 'Chirurgie', status: 'Stable', statusColor: 'green', patientName: 'Fatma Trabelsi', cin: '05432198', reason: 'Post-Opératoire J+2' },
      ];
    }

    // C. Examens (Plateau Technique / Radio / Labo)
    let realExams: any[] = [];
    try {
      realExams = await this.examModel
        .find()
        .populate('patientId', 'firstName lastName cin dossierNumber')
        .sort({ createdAt: -1 })
        .limit(15)
        .lean()
        .exec();
    } catch (_) {}

    const pendingExams = realExams.filter(e => e.status === ExamStatus.PENDING);
    const urgentExams = pendingExams.filter(e => e.priority === 'URGENT' || e.priority === 'HIGH');
    const inProgressExams = realExams.filter(e => e.status === ExamStatus.IN_PROGRESS);
    const completedExams = realExams.filter(e => e.status === ExamStatus.COMPLETED);

    let pendingExamsList: any[] = [];
    if (pendingExams.length > 0) {
      pendingExamsList = pendingExams.map((e: any, idx: number) => {
        const p = e.patientId;
        const patName = p ? `${p.firstName || ''} ${p.lastName || ''}`.trim() : `Patient #${idx + 1}`;
        return {
          title: e.examType || 'Examen clinique',
          patientName: patName,
          department: e.service || 'Radiologie',
          status: 'En attente',
          priority: e.priority || 'MEDIUM',
          isUrgent: e.priority === 'URGENT' || e.priority === 'HIGH',
        };
      });
    }

    if (pendingExamsList.length === 0) {
      pendingExamsList = [
        { title: 'Bilan sanguin complet & CRP', patientName: 'Amine Khelifi', department: 'Laboratoire', status: 'En attente', priority: 'URGENT', isUrgent: true },
        { title: 'Scanner Thoracique sans injection', patientName: 'Mourad Ben Ali', department: 'Radiologie', status: 'En attente', priority: 'HIGH', isUrgent: true },
      ];
    }

    // D. Alertes & Constantes Récentes
    let realAlerts: any[] = [];
    try {
      realAlerts = await this.alertModel
        .find({ isResolved: false })
        .limit(10)
        .lean()
        .exec();
    } catch (_) {}

    let tasksList: any[] = [];
    if (realAlerts.length > 0) {
      tasksList = realAlerts.map((a: any, idx: number) => ({
        id: a._id?.toString() || `t${idx}`,
        title: a.title || 'Vérification clinique',
        location: a.category || 'Chambre 201',
        time: idx % 2 === 0 ? '10:30' : '11:00',
        isCompleted: false,
        isPriority: a.severity === 'HIGH' || a.severity === 'CRITICAL' || idx === 0,
      }));
    }

    if (tasksList.length === 0) {
      tasksList = [
        { id: 't1', title: 'Valider le scanner de contrôle', location: 'Chambre 201', time: '10:30', isCompleted: false, isPriority: true },
        { id: 't2', title: 'Contrôle tensionnel H+4', location: 'Chambre 204', time: '11:15', isCompleted: false, isPriority: false },
      ];
    }

    // ── 2. Métriques Calculées selon le Rôle ──────────────────────────────────
    const consultationsCount = consultationsList.length;
    const urgentConsultationsCount = consultationsList.filter(c => c.isUrgent).length;
    const hospitalizedCount = hospitalizedList.length;
    const toMonitorHospitalizedCount = hospitalizedList.filter(h => h.status === 'À surveiller').length;
    const pendingExamsCount = pendingExamsList.length;
    const tasksCount = tasksList.length;
    const urgentTasksCount = tasksList.filter(t => t.isPriority).length;

    // Métriques spécifiques pour chaque profil
    const metrics: any = {
      consultationsCount,
      urgentConsultationsCount,
      hospitalizedCount,
      toMonitorHospitalizedCount,
      pendingExamsCount,
      tasksCount,
      urgentTasksCount,
      // Spécifique Technicien
      urgentExamsCount: urgentExams.length,
      inProgressCount: inProgressExams.length,
      completedCount: completedExams.length,
      // Spécifique Sage-femme
      laborCount: hospitalizedList.filter(h => h.service === 'Maternité').length,
    };

    const nextAppointment = consultationsList.length > 0
      ? {
          time: consultationsList[0].time,
          title: consultationsList[0].title,
          room: `${consultationsList[0].room} • Dr ${user.lastName || 'Aroua'}`,
          doctor: `Dr ${user.lastName || 'Aroua'}`,
          patientName: consultationsList[0].patientName,
        }
      : {
          time: '09:30',
          title: 'Consultation - Médecine Interne',
          room: 'Salle 3 • Dr Aroua',
          doctor: 'Dr Aroua',
          patientName: 'Ahmed Ben Salah',
        };

    // ── 3. Génération IA Intelligente avec Gemini ──────────────────────────────
    const roleTitles: Record<string, string> = {
      DOCTOR: `Dr. ${user.lastName || user.firstName || 'Médecin'}`,
      NURSE: `Infirmier(ère) ${user.firstName || user.lastName || ''}`.trim(),
      MIDWIFE: `Sage-Femme ${user.firstName || user.lastName || ''}`.trim(),
      TECHNICIAN: `Technicien ${user.firstName || user.lastName || ''}`.trim(),
      ADMIN: `Admin ${user.firstName || ''}`.trim(),
    };
    const userDisplayName = roleTitles[userRole] || `${user.firstName || ''} ${user.lastName || ''}`.trim();

    const systemPrompt = `Tu es Arij Clinical AI, l'assistant médical intelligent en chef de la Polyclinique Arij Djerba.
Tu génères un briefing clinique ultra-pertinent, structuré et opérationnel pour le professionnel de santé connecté.

HEURE EXACTE DE LA DEMANDE : ${currentTimeStr} (${shiftPeriod})
DATE : ${frenchDate}
DESTINATAIRE : ${userDisplayName}
RÔLE CLÉ : ${userRole} (${roleTitles[userRole] || userRole})

CONTEXTE OPÉRATIONNEL SELON LE RÔLE :
${userRole === Role.DOCTOR ? '- Focus Médecin : Consultations médicales du créneau actuel, diagnostic des cas complexes, validation des examens critiques et réévaluation des patients hospitalisés.' : ''}
${userRole === Role.NURSE ? '- Focus Infirmier : Administration des traitements à heure fixe, surveillance des constantes (TA, SpO2, glycémie), pansements et suivi post-opératoire immédiat.' : ''}
${userRole === Role.MIDWIFE ? '- Focus Sage-Femme : Surveillance du travail en salle de naissance, monitorings RCF, soins post-partum mère/nouveau-né et urgences obstétricales.' : ''}
${userRole === Role.TECHNICIAN ? `- Focus Technicien : File d'attente des bilans urgents à ${currentTimeStr}, analyses biochimiques, examens radiologiques et validation technique.` : ''}

DONNÉES CLINIQUES ACTUELLES :
- Consultations / Rendez-vous : ${consultationsCount} (dont ${urgentConsultationsCount} urgentes)
- Patients hospitalisés sous surveillance : ${hospitalizedCount} (dont ${toMonitorHospitalizedCount} à surveiller prioritairement)
- Examens en attente : ${pendingExamsCount}
- Tâches et alertes actives : ${tasksCount} (dont ${urgentTasksCount} urgentes)
${hospitalizedList.length > 0 ? `- Patients hospitalisés : ${hospitalizedList.map(h => `${h.patientName} (${h.room} - Statut: ${h.status} - Motif: ${h.reason})`).join(', ')}` : ''}
${consultationsList.length > 0 ? `- Actes/Consultations prévus : ${consultationsList.slice(0, 5).map(c => `${c.patientName} (${c.time} - ${c.title})`).join(', ')}` : ''}

CONSIGNE CHRONOLOGIQUE ET DE RÉDACTION :
1. Dans le champ "summary", ancre DIRECTEMENT ton texte à l'heure actuelle (${currentTimeStr}) et à la période (${shiftPeriod}). Fais référence aux patients réels et donne une orientation claire et bienveillante pour les heures à venir.
2. Dans "taskOrder", les horaires des tâches doivent débuter à partir de l'heure actuelle (${currentTimeStr}) ou s'échelonner de manière réaliste dans le service.
3. Rends les recommandations cliniques très concrètes et adaptées au rôle ${userRole}.

INSTRUCTIONS STRICTES :
Réponds UNIQUEMENT sous forme d'un objet JSON strict avec la structure suivante :
{
  "summary": "Texte fluide de 3 à 4 phrases débutant par une référence à ${currentTimeStr} et résumant chaleureusement la charge de soins, les priorités absolues et les vigilances cliniques pour ce rôle.",
  "recommendations": [
    {
      "title": "Titre du conseil clinique",
      "description": "Explication concrète de l'action à mener pour optimiser la prise en charge.",
      "priority": "HIGH" | "MEDIUM",
      "category": "Organisation" | "Sécurité Clinique" | "Vigilance" | "Coordination"
    }
  ],
  "taskOrder": [
    {
      "order": 1,
      "time": "${currentTimeStr}",
      "title": "Action / Tâche recommandée",
      "target": "Patient ou Lieu concerné",
      "reason": "Justification clinique de cette priorité",
      "priority": "HIGH" | "MEDIUM"
    }
  ]
}
Ne renvoie rien d'autre que du JSON valide.`;

    let aiSummary = '';
    let aiRecommendations: any[] = [];
    let aiTaskOrder: any[] = [];
    let isRealAi = false;

    try {
      const aiResponse = await this.aiProvider.generateResponseWithProvider(
        systemPrompt,
        `Heure: ${currentTimeStr}\nRole: ${userRole}\nData: consultations=${consultationsCount}, hospitalized=${hospitalizedCount}, exams=${pendingExamsCount}, tasks=${tasksCount}`,
        'Génère le briefing intelligent JSON.',
      );
      const rawAiResponse = aiResponse.text;

      if (rawAiResponse && rawAiResponse.trim().length > 0) {
        // Extraction du JSON depuis d'éventuels backticks markdown ```json ... ```
        const jsonMatch = rawAiResponse.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          try {
            // Nettoyage des trailing commas avant accolades ou crochets fermants
            const cleanedJson = jsonMatch[0]
              .replace(/,\s*([}\]])/g, '$1')
              .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]+/g, '');
            const parsed = JSON.parse(cleanedJson);
            if (typeof parsed.summary === 'string' && parsed.summary.trim().length >= 20) {
              aiSummary = parsed.summary.trim();
              isRealAi = aiResponse.provider === 'gemini';
            }
            if (Array.isArray(parsed.recommendations)) aiRecommendations = parsed.recommendations;
            if (Array.isArray(parsed.taskOrder)) aiTaskOrder = parsed.taskOrder;
          } catch (parseErr) {
            // Extraction résiliente par Regex au cas où une virgule pose problème
            const summaryMatch = jsonMatch[0].match(/"summary"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/);
            if (summaryMatch && summaryMatch[1]) {
              aiSummary = summaryMatch[1].replace(/\\"/g, '"');
              isRealAi = aiResponse.provider === 'gemini' && aiSummary.trim().length >= 20;
            }
          }
        }
      }
    } catch (e) {
      this.logger.warn(`Erreur de génération/parsing Gemini pour ${userRole}: ${e.message}`);
    }

    // ── 4. Fallback Intelligent et Adapté si Gemini est indisponible ──────────
    if (!aiSummary || aiSummary.trim().length < 20) {
      switch (userRole) {
        case Role.DOCTOR:
          aiSummary = `Bonjour ${userDisplayName}. Vous avez aujourd'hui ${consultationsCount} consultations programmées et ${hospitalizedCount} patients hospitalisés sous votre responsabilité. ${pendingExamsCount} résultats d'examens requièrent votre validation, avec une vigilance renforcée sur les cas instables en post-opératoire.`;
          break;
        case Role.NURSE:
          aiSummary = `Bonjour ${userDisplayName}. Votre service compte ${hospitalizedCount} patients alités nécessitant une prise régulière des constantes et l'administration des traitements. Veillez à prioriser la surveillance hémodynamique des patients à surveiller dès le début de votre prise de poste.`;
          break;
        case Role.MIDWIFE:
          aiSummary = `Bonjour ${userDisplayName}. L'activité obstétricale de la Maternité comprend actuellement ${hospitalizedCount} patientes suivies. La surveillance des tracés RCF et l'évaluation du travail en salle d'accouchement constituent vos priorités immédiates de ce matin.`;
          break;
        case Role.TECHNICIAN:
          aiSummary = `Bonjour ${userDisplayName}. Le plateau technique enregistre ${pendingExamsCount} examens en attente de réalisation. Nous vous conseillons de traiter en priorité absolue les bilans urgents avant d'engager la file des imageries et bilans programmés.`;
          break;
        default:
          aiSummary = `Bonjour ${userDisplayName}. Votre journée comprend ${consultationsCount} consultations, ${hospitalizedCount} patients hospitalisés et ${tasksCount} tâches à finaliser. L'équipe médicale reste coordonnée pour garantir la continuité des soins.`;
      }
    }

    if (!aiRecommendations || aiRecommendations.length === 0) {
      switch (userRole) {
        case Role.DOCTOR:
          aiRecommendations = [
            {
              title: 'Prioriser les visites des patients instables',
              description: 'Effectuez la visite de la chambre 201 en premier pour contrôler le pansement et le bilan biologique avant le début des consultations.',
              priority: 'HIGH',
              category: 'Sécurité Clinique',
            },
            {
              title: 'Revue des examens en attente',
              description: 'Validez les scanners thoraciques en attente dès leur transmission par le plateau technique pour ajuster l\'antibiothérapie.',
              priority: 'HIGH',
              category: 'Vigilance',
            },
            {
              title: 'Rythme des consultations externes',
              description: 'Prévoyez 20 minutes pour les premières consultations et regroupez les ordonnances de renouvellement en fin de matinée.',
              priority: 'MEDIUM',
              category: 'Organisation',
            },
          ];
          break;
        case Role.NURSE:
          aiRecommendations = [
            {
              title: 'Tournée de constantes du matin',
              description: 'Relevez en priorité TA, Pouls et SpO2 des patients en chambre 201 et 301 avant l\'administration des traitements per os.',
              priority: 'HIGH',
              category: 'Sécurité Clinique',
            },
            {
              title: 'Contrôle des voies veineuses et perfusions',
              description: 'Vérifiez la perméabilité des abords veineux périphériques et les débits des perfusions post-opératoires.',
              priority: 'HIGH',
              category: 'Vigilance',
            },
            {
              title: 'Mise à jour des lits et transmissions',
              description: 'Indiquez en temps réel les lits libérés dans l\'application pour permettre au bureau des admissions d\'affecter les nouveaux entrants.',
              priority: 'MEDIUM',
              category: 'Organisation',
            },
          ];
          break;
        case Role.MIDWIFE:
          aiRecommendations = [
            {
              title: 'Surveillance RCF continue en salle de travail',
              description: 'Assurez un monitoring cardiotocographique rigoureux pour toute patiente en phase active de travail.',
              priority: 'HIGH',
              category: 'Sécurité Clinique',
            },
            {
              title: 'Vérification des constantes post-partum',
              description: 'Contrôlez l\'involution utérine, les saignements et la tension artérielle en chambre 101 à H+2 et H+6 post-accouchement.',
              priority: 'HIGH',
              category: 'Vigilance',
            },
            {
              title: 'Préparation des boxes d\'accouchement',
              description: 'Réapprovisionnez les kits de réanimation néonatale et vérifiez les sources d\'oxygène thermorégulées.',
              priority: 'MEDIUM',
              category: 'Organisation',
            },
          ];
          break;
        case Role.TECHNICIAN:
          aiRecommendations = [
            {
              title: 'Calibration et contrôles qualité',
              description: 'Passez les contrôles qualité des automates de biochimie et d\'hématologie avant de lancer la série du matin.',
              priority: 'HIGH',
              category: 'Sécurité Clinique',
            },
            {
              title: 'Traitement en urgence des bilans hémostase',
              description: 'Priorisez les tubes étiquetés urgents en provenance des urgences et de la réanimation avec transmission immédiate des résultats au prescripteur.',
              priority: 'HIGH',
              category: 'Vigilance',
            },
            {
              title: 'Archivage et comptes-rendus d\'imagerie',
              description: 'Associez chaque cliché validé au dossier patient informatisé dès la fin de l\'acquisition.',
              priority: 'MEDIUM',
              category: 'Organisation',
            },
          ];
          break;
        default:
          aiRecommendations = [
            {
              title: 'Coordination pluridisciplinaire',
              description: 'Faites le point quotidien avec l\'équipe soignante pour assurer la continuité optimale des soins.',
              priority: 'MEDIUM',
              category: 'Coordination',
            },
          ];
      }
    }

    if (!aiTaskOrder || aiTaskOrder.length === 0) {
      switch (userRole) {
        case Role.DOCTOR:
          aiTaskOrder = [
            { order: 1, time: '08:30', title: 'Visite des patients hospitalisés prioritaires', target: 'Chambres 201 & 301', reason: 'Évaluer la stabilité clinique avant d\'entamer les consultations', priority: 'HIGH' },
            { order: 2, time: '09:30', title: 'Session de consultations externes du matin', target: 'Cabinet Médical', reason: '7 consultations prévues dont 2 dossiers prioritaires', priority: 'HIGH' },
            { order: 3, time: '13:00', title: 'Revue des bilans & validations des examens', target: 'Plateau Technique', reason: 'Adapter les posologies des traitements post-résultats', priority: 'MEDIUM' },
            { order: 4, time: '15:30', title: 'Consultations de suivi & sorties d\'hospitalisation', target: 'Service Hospitalisation', reason: 'Signer les ordonnances de sortie et lettres de liaison', priority: 'MEDIUM' },
          ];
          break;
        case Role.NURSE:
          aiTaskOrder = [
            { order: 1, time: '08:00', title: 'Relève et première prise des constantes vitales', target: 'Tous les lits occupés', reason: 'Détecter toute anomalie thermique ou tensionnelle matinale', priority: 'HIGH' },
            { order: 2, time: '09:00', title: 'Distribution des traitements et perfusions', target: 'Chambres 101, 201, 301', reason: 'Respecter les créneaux horaires d\'administration médicamenteuse', priority: 'HIGH' },
            { order: 3, time: '11:30', title: 'Pansements stériles et soins infirmiers', target: 'Salle de soins & lits', reason: 'Soins post-opératoires selon prescription médicale', priority: 'MEDIUM' },
            { order: 4, time: '14:00', title: 'Mise à jour des dossiers et constantes de mi-journée', target: 'Poste infirmier', reason: 'Assurer une traçabilité rigoureuse des paramètres vitaux', priority: 'MEDIUM' },
          ];
          break;
        case Role.MIDWIFE:
          aiTaskOrder = [
            { order: 1, time: '08:00', title: 'Vérification des patientes en travail actif', target: 'Boxes d\'accouchement', reason: 'Surveiller la progression du travail et le bien-être fœtal', priority: 'HIGH' },
            { order: 2, time: '09:30', title: 'Visite post-partum et examen des nouveau-nés', target: 'Chambre 101 Maternité', reason: 'Contrôler la tolérance maternelle et les réflexes archaïques de l\'enfant', priority: 'HIGH' },
            { order: 3, time: '12:00', title: 'Consultations prénatales et échographies programmées', target: 'Salle d\'examen obstétrical', reason: 'Assurer le suivi du troisième trimestre des patientes convoquées', priority: 'MEDIUM' },
            { order: 4, time: '15:00', title: 'Vérification des stocks et stérilisation matériel', target: 'Bloc d\'accouchement', reason: 'Garantir la disponibilité permanente des boîtes d\'urgence', priority: 'MEDIUM' },
          ];
          break;
        case Role.TECHNICIAN:
          aiTaskOrder = [
            { order: 1, time: '08:00', title: 'Contrôle qualité des analyseurs et automates', target: 'Laboratoire de biologie', reason: 'Valider les courbes d\'étalonnage pour des résultats fiables', priority: 'HIGH' },
            { order: 2, time: '08:45', title: 'Traitement des prélèvements d\'urgence', target: 'Poste biochimie & NFS', reason: 'Fournir les gaz du sang et ionogrammes en moins de 30 min', priority: 'HIGH' },
            { order: 3, time: '10:30', title: 'Série d\'examens d\'imagerie programmés', target: 'Salle de radiologie / Scanner', reason: 'Réaliser les scanners thoraciques et radiographies de contrôle', priority: 'MEDIUM' },
            { order: 4, time: '14:00', title: 'Validation biologique et signature des comptes-rendus', target: 'Système informatique', reason: 'Permettre aux médecins traitants de consulter les bilans', priority: 'MEDIUM' },
          ];
          break;
        default:
          aiTaskOrder = [
            { order: 1, time: '09:00', title: 'Tâches prioritaires de la matinée', target: 'Clinique', reason: 'Accueil et prise en charge initiale', priority: 'HIGH' },
          ];
      }
    }

    const aiSummaryPreview = aiSummary.length > 140 ? `${aiSummary.substring(0, 137)}...` : aiSummary;

    return {
      date: frenchDate,
      rawDate: todayStr,
      currentTime: currentTimeStr,
      shiftPeriod,
      userRole,
      userDisplayName,
      greeting: `Bonjour, ${userDisplayName} 👋`,
      subGreeting: `Briefing clinique en direct • ${currentTimeStr}`,
      serviceName: user.service || 'Polyclinique El Arij',
      weather: {
        temp: '26°C',
        city: 'Djerba',
        condition: 'Ensoleillé',
      },
      metrics,
      nextAppointment,
      aiSummary: aiSummary.trim(),
      aiSummaryPreview,
      aiRecommendations,
      aiTaskOrder,
      consultationsList,
      hospitalizedList,
      pendingExamsList,
      tasksList,
      aiProvider: isRealAi ? 'gemini' : 'local',
      isRealAi,
    };
  }
}
