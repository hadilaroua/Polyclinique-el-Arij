import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Role } from '../../common/enums/role.enum';
import { Appointment, AppointmentDocument } from '../../appointments/schemas/appointment.schema';
import { HospitalStay, HospitalStayDocument, StayStatus } from '../../hospitalization/schemas/hospital-stay.schema';
import { ExamStatus } from '../../exams/schemas/exam.schema';
import { Exam, ExamDocument } from '../../exams/schemas/exam.schema';
import { Alert, AlertDocument } from '../../alerts/schemas/alert.schema';
import { Doctor, DoctorDocument } from '../../doctors/schemas/doctor.schema';
import { AiProviderService } from './ai-provider.service';

@Injectable()
export class DailyBriefingService {
  constructor(
    @InjectModel(Appointment.name) private appointmentModel: Model<AppointmentDocument>,
    @InjectModel(HospitalStay.name) private stayModel: Model<HospitalStayDocument>,
    @InjectModel(Exam.name) private examModel: Model<ExamDocument>,
    @InjectModel(Alert.name) private alertModel: Model<AlertDocument>,
    @InjectModel(Doctor.name) private doctorModel: Model<DoctorDocument>,
    private aiProvider: AiProviderService,
  ) {}

  async generateBriefing(user: any): Promise<any> {
    const userId = user._id || user.id || user.sub;
    const userRole = (user.role || 'STAFF').toUpperCase();

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const stats: any = {};
    const contextParts: string[] = [];
    contextParts.push(`Utilisateur: ${user.firstName || ''} ${user.lastName || ''} (Rôle: ${userRole})`);
    contextParts.push(`Date du jour: ${today.toLocaleDateString('fr-FR')}`);

    const todayStr = today.toISOString().split('T')[0];

    let doctorRecord: any = null;
    if (userRole === Role.DOCTOR) {
      doctorRecord = await this.doctorModel.findOne({ userId }).exec();
    }
    const docIds = [userId];
    if (doctorRecord?._id) docIds.push(doctorRecord._id);

    // 1. Consultations / RDV aujourd'hui
    if (userRole === Role.DOCTOR) {
      const apptsCount = await this.appointmentModel.countDocuments({
        date: todayStr,
        doctorId: { $in: docIds },
      });
      stats.consultations = apptsCount;
      contextParts.push(`Nombre de consultations prévues aujourd'hui pour ce médecin: ${apptsCount}`);
    } else if (userRole === Role.ADMIN) {
      const apptsCount = await this.appointmentModel.countDocuments({ date: todayStr });
      stats.consultations = apptsCount;
      contextParts.push(`Total consultations prévues aujourd'hui dans la clinique: ${apptsCount}`);
    } else {
      stats.consultations = 0;
    }

    // 2. Patients hospitalisés suivis
    let stayQuery: any = { status: StayStatus.ACTIVE };
    if (userRole === Role.DOCTOR) {
      const docService = doctorRecord?.service || user.service;
      const orConds: any[] = [{ attendingDoctorId: { $in: docIds } }];
      if (docService) orConds.push({ service: docService });
      stayQuery = { status: StayStatus.ACTIVE, $or: orConds };
    } else if (userRole === Role.MIDWIFE) {
      stayQuery = { status: StayStatus.ACTIVE, service: new RegExp('Gynécologie|Maternité|Obstétrique', 'i') };
    }
    const activeStays = await this.stayModel.countDocuments(stayQuery);
    stats.hospitalized = activeStays;
    stats.activeStays = activeStays;
    contextParts.push(`Patients hospitalisés sous la charge de ce soignant: ${activeStays}`);

    // 3. Examens / Résultats
    if (userRole === Role.TECHNICIAN) {
      const pendingExams = await this.examModel.countDocuments({ status: ExamStatus.PENDING });
      stats.pendingExams = pendingExams;
      contextParts.push(`Nombre d'examens en attente de réalisation technique: ${pendingExams}`);
    } else if (userRole === Role.DOCTOR) {
      const availableResults = await this.examModel.countDocuments({
        status: ExamStatus.COMPLETED,
        $or: [{ doctorId: { $in: docIds } }, { requestingDoctorId: { $in: docIds } }],
      });
      stats.availableResults = availableResults;
      stats.pendingExams = availableResults;
      contextParts.push(`Résultats d'examens complétés disponibles pour ce médecin: ${availableResults}`);
    }

    // 4. Alertes urgentes non résolues
    let alertQuery: any = { isResolved: false };
    if (userRole === Role.DOCTOR) {
      alertQuery = {
        isResolved: false,
        $or: [
          { targetRoles: 'DOCTOR' },
          { targetDoctorId: userId },
          ...(doctorRecord?._id ? [{ targetDoctorId: doctorRecord._id }] : []),
        ],
      };
    } else if (userRole === Role.NURSE) {
      alertQuery = { isResolved: false, targetRoles: 'NURSE' };
    } else if (userRole === Role.MIDWIFE) {
      alertQuery = { isResolved: false, targetRoles: 'MIDWIFE' };
    } else if (userRole === Role.TECHNICIAN) {
      alertQuery = { isResolved: false, targetRoles: 'TECHNICIAN' };
    }
    const activeAlerts = await this.alertModel.countDocuments(alertQuery);
    stats.activeAlerts = activeAlerts;
    stats.urgentAlerts = activeAlerts;
    contextParts.push(`Alertes non résolues à vérifier pour ce soignant: ${activeAlerts}`);

    // Utilisation de l'IA pour générer les priorités
    const systemPrompt = `Tu es Arij Assistant. Basé sur les statistiques de la journée, donne 3 courtes priorités d'action sous forme de liste numérotée. Sois concis et professionnel. Ne mets pas de blabla.`;
    const aiPrioritiesText = await this.aiProvider.generateResponse(systemPrompt, contextParts.join('\n'), 'Génère les priorités.');
    
    // Parse les priorités (on s'attend à du texte avec des retours à la ligne, on peut juste le passer tel quel au frontend)
    stats.prioritiesText = aiPrioritiesText;

    return stats;
  }
}
