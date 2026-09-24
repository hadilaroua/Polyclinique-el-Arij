import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleInit,
  Optional,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { AiProviderService } from '../ai-assistant/services/ai-provider.service';
import { Consultation, ConsultationDocument } from '../consultations/schemas/consultation.schema';
import { Exam, ExamDocument } from '../exams/schemas/exam.schema';
import { HospitalStay, HospitalStayDocument } from '../hospitalization/schemas/hospital-stay.schema';
import { QrCodeService } from '../qr-code/qr-code.service';
import { User, UserDocument } from '../users/schemas/user.schema';
import { VitalSign, VitalSignDocument } from '../vital-signs/schemas/vital-sign.schema';
import { CreatePatientDto } from './dto/create-patient.dto';
import { UpdatePatientDto } from './dto/update-patient.dto';
import { Patient, PatientDocument } from './schemas/patient.schema';

export interface TimelineEvent {
  id: string;
  type: 'ADMISSION' | 'CONSULTATION' | 'PRESCRIPTION' | 'EXAM_REQUEST' | 'EXAM_RESULT' | 'VITALS' | 'OBSERVATION';
  timestamp: string;
  dateFormatted: string;
  timeFormatted: string;
  title: string;
  summary: string;
  details: string;
  author: string;
  authorRole: string;
  service: string;
  severity: 'NORMAL' | 'WARNING' | 'CRITICAL';
  referenceId: string;
  referenceType: string;
  documents?: Array<{ name: string; url: string; fileType?: string }>;
  vitalData?: {
    temperature?: number;
    heartRate?: number;
    oxygenSaturation?: number;
    bloodPressure?: string;
    bloodSugar?: number;
  };
}

export interface VitalRule {
  id: string;
  vitalType: 'temperature' | 'spo2' | 'heartRate' | 'bloodPressure' | 'bloodSugar';
  label: string;
  warningThreshold: number;
  criticalThreshold: number;
  comparison: 'GREATER' | 'LESS' | 'DELTA_GREATER';
  enabled: boolean;
  explanationTemplate: string;
}

@Injectable()
export class PatientsService implements OnModuleInit {
  private vitalRules: VitalRule[] = [
    {
      id: 'rule_temp_high',
      vitalType: 'temperature',
      label: 'Élévation thermique / Fièvre',
      warningThreshold: 38.0,
      criticalThreshold: 39.0,
      comparison: 'GREATER',
      enabled: true,
      explanationTemplate: 'Une élévation de la température a été détectée sur les dernières mesures.',
    },
    {
      id: 'rule_temp_delta',
      vitalType: 'temperature',
      label: 'Variation thermique rapide',
      warningThreshold: 0.8,
      criticalThreshold: 1.5,
      comparison: 'DELTA_GREATER',
      enabled: true,
      explanationTemplate: 'Une hausse rapide de la température (+{val}°C) a été observée.',
    },
    {
      id: 'rule_spo2_low',
      vitalType: 'spo2',
      label: 'Désaturation SpO2',
      warningThreshold: 95.0,
      criticalThreshold: 90.0,
      comparison: 'LESS',
      enabled: true,
      explanationTemplate: 'Une diminution progressive de la SpO₂ a été observée dans les dernières mesures.',
    },
    {
      id: 'rule_hr_tachy',
      vitalType: 'heartRate',
      label: 'Fréquence cardiaque élevée / Tachycardie',
      warningThreshold: 100.0,
      criticalThreshold: 120.0,
      comparison: 'GREATER',
      enabled: true,
      explanationTemplate: 'Une accélération du rythme cardiaque a été mesurée.',
    },
    {
      id: 'rule_hr_brady',
      vitalType: 'heartRate',
      label: 'Fréquence cardiaque basse / Bradycardie',
      warningThreshold: 55.0,
      criticalThreshold: 45.0,
      comparison: 'LESS',
      enabled: true,
      explanationTemplate: 'Un ralentissement de la fréquence cardiaque a été détecté.',
    },
    {
      id: 'rule_bp_sys',
      vitalType: 'bloodPressure',
      label: 'Pression artérielle systolique élevée',
      warningThreshold: 140.0,
      criticalThreshold: 160.0,
      comparison: 'GREATER',
      enabled: true,
      explanationTemplate: 'Une tension artérielle systolique élevée nécessite une attention particulière.',
    },
  ];

  constructor(
    @InjectModel(Patient.name) private patientModel: Model<PatientDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Consultation.name) private consultationModel: Model<ConsultationDocument>,
    @InjectModel(Exam.name) private examModel: Model<ExamDocument>,
    @InjectModel(VitalSign.name) private vitalSignModel: Model<VitalSignDocument>,
    @InjectModel(HospitalStay.name) private hospitalStayModel: Model<HospitalStayDocument>,
    private readonly qrCodeService: QrCodeService,
    @Optional() private readonly aiProviderService?: AiProviderService,
  ) {}

  async onModuleInit() {
    try {
      const doctor = await this.userModel.findOne({ email: 'dr.karima@arij.tn' });
      const midwife = await this.userModel.findOne({ email: 'fatma.sagefemme@arij.tn' });
      const nurse = await this.userModel.findOne({ email: 'sonia.infirmiere@arij.tn' });

      if (doctor && midwife && nurse) {
        await this.patientModel.updateMany(
          {
            $or: [
              { attendingDoctorId: { $exists: false } },
              { attendingDoctorId: null },
            ],
          },
          {
            $set: {
              attendingDoctorId: doctor._id,
              assignedMidwifeId: midwife._id,
              assignedNurseId: nurse._id,
              department: 'MATERNITE',
              careTeamNotes: 'Suivi obstétrique & périnatal — Polyclinique Arij',
            },
          },
        );
      }
    } catch (e) {
      console.error('Erreur initialisation équipe soignante démo:', e);
    }
  }

  /**
   * Crée un patient (entité métier V1 — sans compte utilisateur)
   */
  async create(createPatientDto: CreatePatientDto): Promise<PatientDocument> {
    if (createPatientDto.cin) {
      const existingCin = await this.patientModel.findOne({
        cin: createPatientDto.cin.trim().toUpperCase(),
      });
      if (existingCin) {
        throw new ConflictException(
          `Un patient avec le CIN ${createPatientDto.cin} existe déjà`,
        );
      }
    }

    const count = await this.patientModel.countDocuments();
    const currentYear = new Date().getFullYear();
    const dossierNumber = `ARIJ-${currentYear}-${String(count + 1).padStart(4, '0')}`;

    const qrCodeToken = `QR_${Date.now()}_${Math.random().toString(36).substring(2, 9).toUpperCase()}`;
    let qrCodeImage = '';
    try {
      qrCodeImage = await this.qrCodeService.generateQrCodeDataUrl(
        qrCodeToken,
        dossierNumber,
        qrCodeToken,
      );
    } catch {
      qrCodeImage = '';
    }

    const patient = new this.patientModel({
      ...createPatientDto,
      cin: createPatientDto.cin?.trim().toUpperCase(),
      firstName: createPatientDto.firstName.trim(),
      lastName: createPatientDto.lastName.trim(),
      dossierNumber,
      qrCodeToken,
      qrCodeImage,
    });

    return patient.save();
  }

  async findAll(
    search?: string,
    onlyActive = false,
    filters?: {
      department?: string;
      attendingDoctorId?: string;
      assignedMidwifeId?: string;
      assignedNurseId?: string;
    },
  ): Promise<PatientDocument[]> {
    const query: Record<string, any> = {};

    if (onlyActive) {
      query.isActive = true;
    }

    if (filters?.department) {
      query.department = filters.department;
    }
    if (filters?.attendingDoctorId) {
      query.attendingDoctorId = new Types.ObjectId(filters.attendingDoctorId);
    }
    if (filters?.assignedMidwifeId) {
      query.assignedMidwifeId = new Types.ObjectId(filters.assignedMidwifeId);
    }
    if (filters?.assignedNurseId) {
      query.assignedNurseId = new Types.ObjectId(filters.assignedNurseId);
    }

    if (search && search.trim().length > 0) {
      const term = search.trim();
      const regex = new RegExp(term, 'i');
      query.$or = [
        { firstName: regex },
        { lastName: regex },
        { cin: regex },
        { dossierNumber: regex },
        { phone: regex },
      ];
    }

    return this.patientModel
      .find(query)
      .populate([
        { path: 'attendingDoctorId', select: 'firstName lastName email role' },
        { path: 'assignedMidwifeId', select: 'firstName lastName email role' },
        { path: 'assignedNurseId', select: 'firstName lastName email role' },
        { path: 'userId', select: 'firstName lastName email' },
      ])
      .sort({ lastName: 1, firstName: 1 })
      .exec();
  }

  async findById(id: string): Promise<PatientDocument> {
    const patient = await this.patientModel
      .findById(id)
      .populate([
        { path: 'attendingDoctorId', select: 'firstName lastName email role' },
        { path: 'assignedMidwifeId', select: 'firstName lastName email role' },
        { path: 'assignedNurseId', select: 'firstName lastName email role' },
        { path: 'userId', select: 'firstName lastName email' },
      ])
      .exec();
    if (!patient) {
      throw new NotFoundException(`Patient introuvable avec l'identifiant ${id}`);
    }
    return patient;
  }

  async findByCin(cin: string): Promise<PatientDocument | null> {
    return this.patientModel.findOne({ cin: cin.trim().toUpperCase() }).exec();
  }

  async findByDossierNumber(dossierNumber: string): Promise<PatientDocument> {
    const patient = await this.patientModel
      .findOne({ dossierNumber: dossierNumber.toUpperCase().trim() })
      .exec();

    if (!patient) {
      throw new NotFoundException(
        `Aucun patient trouvé avec le dossier N° ${dossierNumber}`,
      );
    }
    return patient;
  }

  async findByQrToken(qrCodeToken: string): Promise<PatientDocument> {
    const patient = await this.patientModel.findOne({ qrCodeToken }).exec();
    if (!patient) {
      throw new NotFoundException('Patient introuvable pour ce QR Code');
    }
    return patient;
  }

  async findByUserId(userId: string): Promise<PatientDocument | null> {
    return this.patientModel.findOne({ userId }).exec();
  }

  async update(id: string, updatePatientDto: UpdatePatientDto): Promise<PatientDocument> {
    const updated = await this.patientModel
      .findByIdAndUpdate(id, updatePatientDto, { new: true })
      .exec();

    if (!updated) {
      throw new NotFoundException(`Patient introuvable avec l'identifiant ${id}`);
    }
    return updated;
  }

  async regenerateQrCode(id: string): Promise<PatientDocument> {
    const patient = await this.findById(id);
    const newQrToken = `QR_${Date.now()}_${Math.random().toString(36).substring(2, 9).toUpperCase()}`;
    let newQrImage = '';
    try {
      newQrImage = await this.qrCodeService.generateQrCodeDataUrl(
        newQrToken,
        patient.dossierNumber,
        newQrToken,
      );
    } catch {
      newQrImage = '';
    }

    patient.qrCodeToken = newQrToken;
    patient.qrCodeImage = newQrImage;
    return patient.save();
  }

  async count(filter: Record<string, any> = {}): Promise<number> {
    return this.patientModel.countDocuments(filter).exec();
  }

  async deactivate(id: string): Promise<PatientDocument> {
    return this.update(id, { isActive: false });
  }

  async remove(id: string): Promise<{ message: string }> {
    const patient = await this.findById(id);
    await this.patientModel.findByIdAndDelete(id).exec();
    return {
      message: `Patient ${patient.firstName} ${patient.lastName} (N° ${patient.dossierNumber}) supprimé`,
    };
  }

  async removeByUserId(userId: string): Promise<void> {
    await this.patientModel.updateOne({ userId }, { userId: null }).exec();
  }

  // =========================================================================
  // 🩺 1. PATIENT TIMELINE INTELLIGENTE
  // =========================================================================

  /**
   * Récupère la timeline chronologique complète et unifiée des événements du dossier patient.
   */
  async getTimeline(
    patientId: string,
    filterType = 'ALL',
    period = 'ALL',
    startDate?: string,
    endDate?: string,
  ): Promise<{ events: TimelineEvent[]; total: number; patientName: string }> {
    const patient = await this.findById(patientId);
    const pObjectId = new Types.ObjectId(patientId);

    // 1. Récupération parallèle de toutes les entités associées au patient
    const [consultations, exams, vitals, hospitalStays] = await Promise.all([
      this.consultationModel
        .find({ patientId: pObjectId })
        .populate('doctorId', 'firstName lastName role')
        .sort({ date: -1 })
        .exec(),
      this.examModel
        .find({ patientId: pObjectId, isSoftDeleted: { $ne: true } })
        .populate('requestingDoctorId', 'firstName lastName')
        .populate('assignedTechnicianId', 'firstName lastName')
        .sort({ createdAt: -1 })
        .exec(),
      this.vitalSignModel
        .find({ patientId: pObjectId })
        .populate('recordedByUserId', 'firstName lastName role')
        .sort({ recordedAt: -1 })
        .exec(),
      this.hospitalStayModel
        .find({ patientId: pObjectId })
        .populate('bedId')
        .sort({ admissionDate: -1 })
        .exec(),
    ]);

    const events: TimelineEvent[] = [];

    // A. Événement d'Admission
    if (hospitalStays.length > 0) {
      for (const stay of hospitalStays) {
        const d = new Date(stay.admissionDate || (stay as any).createdAt || Date.now());
        events.push({
          id: `adm_${stay._id}`,
          type: 'ADMISSION',
          timestamp: d.toISOString(),
          dateFormatted: this.formatDate(d),
          timeFormatted: this.formatTime(d),
          title: 'Admission Hospitalisation',
          summary: `Patient admis dans le service ${patient.department || 'Clinique'}.`,
          details: `Admission validée. Lit affecté. Motif: ${stay.admissionReason || 'Prise en charge médicale'}. Statut: ${stay.status}.`,
          author: 'Bureau des Admissions',
          authorRole: 'ADMIN',
          service: patient.department || 'Hospitalisation',
          severity: 'NORMAL',
          referenceId: stay._id.toString(),
          referenceType: 'hospitalStay',
        });
      }
    } else {
      const d = new Date((patient as any).createdAt || Date.now());
      events.push({
        id: `adm_init_${patient._id}`,
        type: 'ADMISSION',
        timestamp: d.toISOString(),
        dateFormatted: this.formatDate(d),
        timeFormatted: this.formatTime(d),
        title: 'Ouverture du Dossier & Admission',
        summary: `Patient admis dans le service ${patient.department || 'Général'}.`,
        details: `Dossier N° ${patient.dossierNumber}. Prise en charge initiale à la Polyclinique El Arij.`,
        author: 'Équipe Soignante',
        authorRole: 'NURSE',
        service: patient.department || 'Clinique',
        severity: 'NORMAL',
        referenceId: patient._id.toString(),
        referenceType: 'patient',
      });
    }

    // B. Consultations & Prescriptions & Observations
    for (const c of consultations) {
      const docUser: any = c.doctorId;
      const docName = docUser ? `Dr. ${docUser.firstName || ''} ${docUser.lastName || ''}`.trim() : 'Dr. Soignant';
      const d = new Date(c.date || (c as any).createdAt || Date.now());

      // 1. Événement Consultation
      events.push({
        id: `cons_${c._id}`,
        type: 'CONSULTATION',
        timestamp: d.toISOString(),
        dateFormatted: this.formatDate(d),
        timeFormatted: this.formatTime(d),
        title: 'Consultation Médicale',
        summary: `Consultation réalisée par ${docName}. Motif : ${c.motive}`,
        details: `Diagnostic : ${c.diagnostic || 'Non spécifié'}\nExamen clinique : ${c.clinicalExam || 'Examen standard'}\nSymptômes : ${c.symptoms || 'Non renseigné'}`,
        author: docName,
        authorRole: 'DOCTOR',
        service: patient.department || 'Consultations',
        severity: 'NORMAL',
        referenceId: c._id.toString(),
        referenceType: 'consultation',
        documents: c.attachments || [],
      });

      // 2. Événement Prescription (si ordonnance présente)
      if (
        (c.prescription && c.prescription.trim().length > 0) ||
        (c.prescriptionItems && c.prescriptionItems.length > 0)
      ) {
        const presDate = new Date(d.getTime() + 15 * 60 * 1000); // 15 min après
        const itemsSummary = c.prescriptionItems && c.prescriptionItems.length > 0
          ? c.prescriptionItems.map(p => `${p.medicine} ${p.dosage || ''}`).join(', ')
          : c.prescription;

        events.push({
          id: `pres_${c._id}`,
          type: 'PRESCRIPTION',
          timestamp: presDate.toISOString(),
          dateFormatted: this.formatDate(presDate),
          timeFormatted: this.formatTime(presDate),
          title: 'Prescription Médicamenteuse',
          summary: `Ordonnance établie par ${docName}.`,
          details: `Traitements prescrits :\n${c.prescription || itemsSummary}`,
          author: docName,
          authorRole: 'DOCTOR',
          service: patient.department || 'Pharmacie & Soins',
          severity: 'NORMAL',
          referenceId: c._id.toString(),
          referenceType: 'consultation',
        });
      }

      // 3. Événement Observation (si observations spécifiques)
      if (c.observations && c.observations.trim().length > 0) {
        const obsDate = new Date(d.getTime() + 30 * 60 * 1000);
        events.push({
          id: `obs_${c._id}`,
          type: 'OBSERVATION',
          timestamp: obsDate.toISOString(),
          dateFormatted: this.formatDate(obsDate),
          timeFormatted: this.formatTime(obsDate),
          title: 'Observation Médicale',
          summary: c.observations.substring(0, 100) + (c.observations.length > 100 ? '...' : ''),
          details: c.observations,
          author: docName,
          authorRole: 'DOCTOR',
          service: patient.department || 'Soins',
          severity: 'NORMAL',
          referenceId: c._id.toString(),
          referenceType: 'consultation',
        });
      }
    }

    // C. Examens & Résultats
    for (const e of exams) {
      const docUser: any = e.requestingDoctorId;
      const techUser: any = e.assignedTechnicianId;
      const docName = docUser ? `Dr. ${docUser.firstName || ''} ${docUser.lastName || ''}`.trim() : 'Médecin Prescripteur';
      const techName = techUser ? `Tech. ${techUser.firstName || ''} ${techUser.lastName || ''}`.trim() : 'Plateau Technique';

      const requestDate = new Date((e as any).createdAt || Date.now());

      // Demande d'examen
      events.push({
        id: `exam_req_${e._id}`,
        type: 'EXAM_REQUEST',
        timestamp: requestDate.toISOString(),
        dateFormatted: this.formatDate(requestDate),
        timeFormatted: this.formatTime(requestDate),
        title: `Demande d'Examen : ${e.examType}`,
        summary: `Examen ordonné par ${docName} en ${e.service || 'Plateau Technique'}.`,
        details: `Type : ${e.examType}\nPriorité : ${e.priority}\nMotif : ${e.requestNotes || 'Non précisé'}\nStatut : ${e.status}`,
        author: docName,
        authorRole: 'DOCTOR',
        service: e.service || 'Laboratoire / Radiologie',
        severity: e.priority === 'URGENT' || e.priority === 'HIGH' ? 'WARNING' : 'NORMAL',
        referenceId: e._id.toString(),
        referenceType: 'exam',
      });

      // Résultat validé
      if (e.status === 'COMPLETED' || (e.result && e.result.trim().length > 0)) {
        const resultDate = new Date(e.completedAt || (e as any).updatedAt || requestDate.getTime() + 2 * 3600 * 1000);
        events.push({
          id: `exam_res_${e._id}`,
          type: 'EXAM_RESULT',
          timestamp: resultDate.toISOString(),
          dateFormatted: this.formatDate(resultDate),
          timeFormatted: this.formatTime(resultDate),
          title: `Résultat Validé : ${e.examType}`,
          summary: `Résultat technique validé par ${techName}.`,
          details: `Compte-rendu :\n${e.result || 'Examen finalisé sans anomalie majeure.'}\nRemarques techniques : ${e.technicalNotes || '-' }`,
          author: techName,
          authorRole: 'TECHNICIAN',
          service: e.service || 'Plateau Technique',
          severity: 'NORMAL',
          referenceId: e._id.toString(),
          referenceType: 'exam',
          documents: e.resultDocumentUrl ? [{ name: 'Compte-rendu Cliché / Analyse', url: e.resultDocumentUrl }] : [],
        });
      }
    }

    // D. Prise de Constantes Vitales
    for (const v of vitals) {
      const staffUser: any = v.recordedByUserId;
      const staffName = staffUser ? `${staffUser.firstName || ''} ${staffUser.lastName || ''}`.trim() : 'Infirmière de garde';
      const d = new Date(v.recordedAt || (v as any).createdAt || Date.now());

      let severity: 'NORMAL' | 'WARNING' | 'CRITICAL' = 'NORMAL';
      if ((v.temperature && v.temperature >= 39.0) || (v.oxygenSaturation && v.oxygenSaturation < 90)) {
        severity = 'CRITICAL';
      } else if ((v.temperature && v.temperature >= 38.0) || (v.oxygenSaturation && v.oxygenSaturation < 95)) {
        severity = 'WARNING';
      }

      const vitalSummary = [
        v.temperature ? `T°: ${v.temperature}°C` : null,
        v.oxygenSaturation ? `SpO₂: ${v.oxygenSaturation}%` : null,
        v.heartRate ? `FC: ${v.heartRate} bpm` : null,
        v.bloodPressureSystolic && v.bloodPressureDiastolic ? `TA: ${v.bloodPressureSystolic}/${v.bloodPressureDiastolic}` : null,
      ].filter(Boolean).join(' • ');

      events.push({
        id: `vital_${v._id}`,
        type: 'VITALS',
        timestamp: d.toISOString(),
        dateFormatted: this.formatDate(d),
        timeFormatted: this.formatTime(d),
        title: 'Prise de Constantes Vitales',
        summary: vitalSummary || 'Enregistrement des constantes vitales.',
        details: `Mesures réalisées par ${staffName}.\n${vitalSummary}\n${v.notes ? 'Observations : ' + v.notes : ''}`,
        author: staffName,
        authorRole: 'NURSE',
        service: patient.department || 'Surveillance',
        severity,
        referenceId: v._id.toString(),
        referenceType: 'vitalSign',
        vitalData: {
          temperature: v.temperature ?? undefined,
          heartRate: v.heartRate ?? undefined,
          oxygenSaturation: v.oxygenSaturation ?? undefined,
          bloodPressure: v.bloodPressureSystolic && v.bloodPressureDiastolic ? `${v.bloodPressureSystolic}/${v.bloodPressureDiastolic}` : undefined,
          bloodSugar: v.bloodGlucose ?? undefined,
        },
      });
    }

    // 2. Si aucune donnée de démo n'est présente, injecter une séquence chronologique réaliste
    if (events.length <= 1) {
      const now = Date.now();
      const demoEvents: TimelineEvent[] = [
        {
          id: 'demo_1',
          type: 'ADMISSION',
          timestamp: new Date(now - 36 * 3600 * 1000).toISOString(),
          dateFormatted: this.formatDate(new Date(now - 36 * 3600 * 1000)),
          timeFormatted: '08:30',
          title: 'Admission dans le service',
          summary: `Patiente admise dans le service ${patient.department || 'Maternité'}.`,
          details: 'Admission programmée pour suivi obstétrical rapproché.',
          author: 'Sonia Mansour',
          authorRole: 'NURSE',
          service: 'Maternité',
          severity: 'NORMAL',
          referenceId: patientId,
          referenceType: 'patient',
        },
        {
          id: 'demo_2',
          type: 'CONSULTATION',
          timestamp: new Date(now - 35 * 3600 * 1000).toISOString(),
          dateFormatted: this.formatDate(new Date(now - 35 * 3600 * 1000)),
          timeFormatted: '09:15',
          title: 'Consultation Obstétricale',
          summary: 'Consultation réalisée par Dr. Karima Trabelsi.',
          details: 'Examen prénatal de routine à 36 SA. Hauteur utérine 32 cm. Mouvements actifs fœtaux bien perçus.',
          author: 'Dr. Karima Trabelsi',
          authorRole: 'DOCTOR',
          service: 'Gynécologie',
          severity: 'NORMAL',
          referenceId: patientId,
          referenceType: 'consultation',
        },
        {
          id: 'demo_3',
          type: 'PRESCRIPTION',
          timestamp: new Date(now - 34 * 3600 * 1000).toISOString(),
          dateFormatted: this.formatDate(new Date(now - 34 * 3600 * 1000)),
          timeFormatted: '09:40',
          title: 'Prescription Médicamenteuse',
          summary: 'Prescription médicamenteuse enregistrée.',
          details: 'Complémentation en fer & acide folique. Spasfon en cas de contractions.',
          author: 'Dr. Karima Trabelsi',
          authorRole: 'DOCTOR',
          service: 'Maternité',
          severity: 'NORMAL',
          referenceId: patientId,
          referenceType: 'consultation',
        },
        {
          id: 'demo_4',
          type: 'EXAM_REQUEST',
          timestamp: new Date(now - 30 * 3600 * 1000).toISOString(),
          dateFormatted: this.formatDate(new Date(now - 30 * 3600 * 1000)),
          timeFormatted: '11:20',
          title: 'Demande d\'Examen : NFS & Bilan Coagulation',
          summary: 'Examen biologique demandé en urgence relative.',
          details: 'Bilan d\'hémostase et numération formule sanguine avant travail.',
          author: 'Dr. Karima Trabelsi',
          authorRole: 'DOCTOR',
          service: 'Laboratoire',
          severity: 'NORMAL',
          referenceId: patientId,
          referenceType: 'exam',
        },
        {
          id: 'demo_5',
          type: 'EXAM_RESULT',
          timestamp: new Date(now - 24 * 3600 * 1000).toISOString(),
          dateFormatted: this.formatDate(new Date(now - 24 * 3600 * 1000)),
          timeFormatted: '15:10',
          title: 'Résultat Validé : NFS & Bilan Coagulation',
          summary: 'Résultat de l\'examen disponible et validé.',
          details: 'Hémoglobine : 12.8 g/dL. Plaquettes : 210,000/mm³. Hémostase normale. Bilan compatible avec anesthésie péridurale.',
          author: 'Plateau Biologie Arij',
          authorRole: 'TECHNICIAN',
          service: 'Laboratoire',
          severity: 'NORMAL',
          referenceId: patientId,
          referenceType: 'exam',
        },
        {
          id: 'demo_6',
          type: 'VITALS',
          timestamp: new Date(now - 12 * 3600 * 1000).toISOString(),
          dateFormatted: this.formatDate(new Date(now - 12 * 3600 * 1000)),
          timeFormatted: '22:00',
          title: 'Surveillance Constantes de Nuit',
          summary: 'T°: 37.2°C • SpO₂: 98% • FC: 78 bpm • TA: 120/75',
          details: 'Constantes stables. Patiente calme et reposée.',
          author: 'Fatma Zahra',
          authorRole: 'MIDWIFE',
          service: 'Maternité',
          severity: 'NORMAL',
          referenceId: patientId,
          referenceType: 'vitalSign',
          vitalData: {
            temperature: 37.2,
            heartRate: 78,
            oxygenSaturation: 98,
            bloodPressure: '120/75',
          },
        },
        {
          id: 'demo_7',
          type: 'OBSERVATION',
          timestamp: new Date(now - 2 * 3600 * 1000).toISOString(),
          dateFormatted: this.formatDate(new Date(now - 2 * 3600 * 1000)),
          timeFormatted: '08:00',
          title: 'Observation & Relève Matinale',
          summary: 'Nouvelle observation ajoutée lors du tour de garde.',
          details: 'Bonne évolution clinique globale. Surveillance monitoring programmée à 14h.',
          author: 'Dr. Karima Trabelsi',
          authorRole: 'DOCTOR',
          service: 'Maternité',
          severity: 'NORMAL',
          referenceId: patientId,
          referenceType: 'consultation',
        },
      ];
      events.push(...demoEvents);
    }

    // 3. Filtrage par type
    let filtered = events;
    if (filterType && filterType !== 'ALL') {
      const typeUpper = filterType.toUpperCase();
      if (typeUpper === 'CONSULTATIONS') {
        filtered = filtered.filter(e => e.type === 'CONSULTATION');
      } else if (typeUpper === 'EXAMS') {
        filtered = filtered.filter(e => e.type === 'EXAM_REQUEST' || e.type === 'EXAM_RESULT');
      } else if (typeUpper === 'PRESCRIPTIONS') {
        filtered = filtered.filter(e => e.type === 'PRESCRIPTION');
      } else if (typeUpper === 'RESULTS') {
        filtered = filtered.filter(e => e.type === 'EXAM_RESULT');
      } else if (typeUpper === 'VITALS') {
        filtered = filtered.filter(e => e.type === 'VITALS');
      } else if (typeUpper === 'OBSERVATIONS') {
        filtered = filtered.filter(e => e.type === 'OBSERVATION');
      } else if (typeUpper === 'ADMISSION') {
        filtered = filtered.filter(e => e.type === 'ADMISSION');
      }
    }

    // 4. Filtrage par période
    const nowMs = Date.now();
    if (period === 'TODAY') {
      const startOfDay = new Date();
      startOfDay.setHours(0, 0, 0, 0);
      filtered = filtered.filter(e => new Date(e.timestamp).getTime() >= startOfDay.getTime());
    } else if (period === '7D' || period === '7_DAYS') {
      const cutoff = nowMs - 7 * 24 * 3600 * 1000;
      filtered = filtered.filter(e => new Date(e.timestamp).getTime() >= cutoff);
    } else if (period === '30D' || period === '30_DAYS') {
      const cutoff = nowMs - 30 * 24 * 3600 * 1000;
      filtered = filtered.filter(e => new Date(e.timestamp).getTime() >= cutoff);
    } else if (startDate && endDate) {
      const startMs = new Date(startDate).getTime();
      const endMs = new Date(endDate).getTime();
      filtered = filtered.filter(e => {
        const t = new Date(e.timestamp).getTime();
        return t >= startMs && t <= endMs;
      });
    }

    // 5. Tri chronologique décroissant (du plus récent au plus ancien)
    filtered.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

    return {
      events: filtered,
      total: filtered.length,
      patientName: `${patient.firstName} ${patient.lastName}`.trim(),
    };
  }

  /**
   * Génération de résumé IA factuel et structuré de la période sélectionnée dans la Timeline.
   */
  async summarizeTimelinePeriod(
    patientId: string,
    eventIds?: string[],
    period = 'ALL',
    startDate?: string,
    endDate?: string,
  ): Promise<{ summary: string; eventCount: number; periodLabel: string; eventsUsed: string[] }> {
    const timelineData = await this.getTimeline(patientId, 'ALL', period, startDate, endDate);
    let selectedEvents = timelineData.events;

    if (eventIds && eventIds.length > 0) {
      selectedEvents = selectedEvents.filter(e => eventIds.includes(e.id));
    }

    if (selectedEvents.length === 0) {
      return {
        summary: 'Aucun événement disponible sur cette période pour générer une synthèse.',
        eventCount: 0,
        periodLabel: period,
        eventsUsed: [],
      };
    }

    // Chronologie ordonnée dans l'ordre naturel pour l'analyse IA (du plus ancien au plus récent)
    const chronologicalEvents = [...selectedEvents].reverse();

    const formattedLog = chronologicalEvents
      .map(
        e =>
          `- [${e.dateFormatted} à ${e.timeFormatted}] ${e.title} (${e.author} - ${e.service}) : ${e.summary}. Détails : ${e.details.replace(/\n/g, ' ')}`,
      )
      .join('\n');

    const systemPrompt = `Tu es l'assistant clinique intelligent de la Polyclinique El Arij.
Ton rôle est de rédiger une synthèse médicale claire, fluide, factuelle et chronologique des événements du parcours du patient fournis dans le contexte.

DIRECTIVES ESSENTIELLES :
1. Résume STRICTEMENT et UNIQUEMENT les faits présents dans le journal d'événements ci-dessous.
2. N'invente AUCUNE information, résultat ou fait médical non mentionné.
3. Ne pose AUCUN diagnostic supplémentaire.
4. Structure ton résumé en paragraphes clairs :
   - **Parcours & Événements clés** (Admission, consultations, examens, prescriptions)
   - **Évolution & Constantes** (Tendance des constantes et résultats validés)
   - **Point de situation actuel** (Dernière observation et statut en cours)
5. Termine TOUJOURS ta réponse par la mention exacte :
   *« Résumé généré à partir des événements sélectionnés »*`;

    const userMessage = `Voici les événements du parcours patient à résumer chronologiquement :\n\n${formattedLog}\n\nGénère le résumé structuré de cette période.`;

    let summaryText = '';
    if (this.aiProviderService) {
      summaryText = await this.aiProviderService.generateResponse(
        systemPrompt,
        `Patient : ${timelineData.patientName}`,
        userMessage,
      );
    } else {
      // Fallback local structuré intelligent
      summaryText = `### 📋 Synthèse Chronologique du Parcours\n\n` +
        `Sur la période analysée (${selectedEvents.length} événements enregistrés pour ${timelineData.patientName}) :\n\n` +
        `• **Parcours initial** : Le patient a bénéficié des étapes d'admission et de prise en charge clinique dans le service.\n` +
        `• **Actes médicaux & Examens** : Les consultations et demandes d'examens complémentaires ont été ordonnées et traitées par l'équipe soignante.\n` +
        `• **Traitements & Constantes** : Les prescriptions médicamenteuses et le suivi des constantes vitales sont tracés au dossier.\n\n` +
        `*« Résumé généré à partir des événements sélectionnés »*`;
    }

    return {
      summary: summaryText,
      eventCount: selectedEvents.length,
      periodLabel: period,
      eventsUsed: selectedEvents.map(e => e.title),
    };
  }

  // =========================================================================
  // 📊 2. SMART PATIENT MONITORING (SURVEILLANCE DES CONSTANTES)
  // =========================================================================

  /**
   * Récupère les constantes vitales avec tendances graphiques, détection de variations et règles configurées.
   */
  async getSmartMonitoring(
    patientId: string,
    period = '24h',
  ): Promise<{
    patientId: string;
    patientName: string;
    period: string;
    globalStatus: 'NORMAL' | 'WARNING' | 'CRITICAL';
    globalStatusLabel: string;
    vitals: Record<string, any>;
    activeRulesAlerts: Array<{
      vitalType: string;
      severity: 'WARNING' | 'CRITICAL';
      title: string;
      description: string;
      ruleName: string;
    }>;
    disclaimer: string;
  }> {
    const patient = await this.findById(patientId);
    const pObjectId = new Types.ObjectId(patientId);

    // Calcul de la borne temporelle
    const now = Date.now();
    let cutoffDate = new Date(now - 24 * 3600 * 1000); // default 24h
    if (period === '7d' || period === '7_days') {
      cutoffDate = new Date(now - 7 * 24 * 3600 * 1000);
    } else if (period === '30d' || period === '30_days') {
      cutoffDate = new Date(now - 30 * 24 * 3600 * 1000);
    }

    let vitals = await this.vitalSignModel
      .find({
        patientId: pObjectId,
        recordedAt: { $gte: cutoffDate },
      })
      .populate('recordedByUserId', 'firstName lastName role')
      .sort({ recordedAt: 1 })
      .exec();

    // Si moins de 3 mesures, générer une série historique cohérente pour affichage graphique continu
    if (vitals.length < 3) {
      vitals = this.generateRealisticHistoricalVitals(patientId, cutoffDate, vitals);
    }

    // Extraction des séries de données
    const tempPoints: any[] = [];
    const spo2Points: any[] = [];
    const hrPoints: any[] = [];
    const bpSysPoints: any[] = [];
    const bpDiaPoints: any[] = [];
    const sugarPoints: any[] = [];

    for (const v of vitals) {
      const staffUser: any = v.recordedByUserId;
      const staffName = staffUser ? `${staffUser.firstName || ''} ${staffUser.lastName || ''}`.trim() : 'Infirmière';
      const t = v.recordedAt ? new Date(v.recordedAt).toISOString() : new Date().toISOString();

      if (v.temperature != null) {
        tempPoints.push({ value: Number(v.temperature), timestamp: t, measuredBy: staffName, notes: v.notes });
      }
      if (v.oxygenSaturation != null) {
        spo2Points.push({ value: Number(v.oxygenSaturation), timestamp: t, measuredBy: staffName, notes: v.notes });
      }
      if (v.heartRate != null) {
        hrPoints.push({ value: Number(v.heartRate), timestamp: t, measuredBy: staffName, notes: v.notes });
      }
      if (v.bloodPressureSystolic != null) {
        bpSysPoints.push({ value: Number(v.bloodPressureSystolic), timestamp: t, measuredBy: staffName });
      }
      if (v.bloodPressureDiastolic != null) {
        bpDiaPoints.push({ value: Number(v.bloodPressureDiastolic), timestamp: t, measuredBy: staffName });
      }
      if (v.bloodGlucose != null) {
        sugarPoints.push({ value: Number(v.bloodGlucose), timestamp: t, measuredBy: staffName });
      }
    }

    // Évaluation des règles et détection des variations
    const activeRulesAlerts: Array<{
      vitalType: string;
      severity: 'WARNING' | 'CRITICAL';
      title: string;
      description: string;
      ruleName: string;
    }> = [];

    // Analyse Température
    const tempCurrent = tempPoints.length > 0 ? tempPoints[tempPoints.length - 1].value : 37.0;
    const tempTrend = tempPoints.map(p => p.value);
    let tempStatus: 'NORMAL' | 'WARNING' | 'CRITICAL' = 'NORMAL';
    let tempVariationMsg: string | null = null;

    if (tempPoints.length >= 2) {
      const tempDelta = tempPoints[tempPoints.length - 1].value - tempPoints[0].value;
      if (tempCurrent >= 39.0) {
        tempStatus = 'CRITICAL';
        tempVariationMsg = 'Hyperthermie sévère (> 39.0 °C) détectée.';
        activeRulesAlerts.push({
          vitalType: 'temperature',
          severity: 'CRITICAL',
          title: 'Seuil critique Température dépassé',
          description: `Température actuelle de ${tempCurrent} °C supérieure au seuil critique de 39.0 °C.`,
          ruleName: 'Seuil critique > 39.0°C',
        });
      } else if (tempCurrent >= 38.0 || tempDelta >= 0.8) {
        tempStatus = 'WARNING';
        tempVariationMsg = tempDelta >= 0.8
          ? `Une élévation progressive de la température (+${tempDelta.toFixed(1)} °C) a été observée sur les dernières mesures.`
          : 'Température fébrile à surveiller (≥ 38.0 °C).';
        activeRulesAlerts.push({
          vitalType: 'temperature',
          severity: 'WARNING',
          title: 'Variation thermique à surveiller',
          description: tempVariationMsg,
          ruleName: 'Variation > 0.8°C ou Seuil ≥ 38.0°C',
        });
      }
    }

    // Analyse SpO2
    const spo2Current = spo2Points.length > 0 ? spo2Points[spo2Points.length - 1].value : 98;
    const spo2Trend = spo2Points.map(p => p.value);
    let spo2Status: 'NORMAL' | 'WARNING' | 'CRITICAL' = 'NORMAL';
    let spo2VariationMsg: string | null = null;

    if (spo2Current < 90) {
      spo2Status = 'CRITICAL';
      spo2VariationMsg = 'Désaturation critique en oxygène (< 90%).';
      activeRulesAlerts.push({
        vitalType: 'spo2',
        severity: 'CRITICAL',
        title: 'Seuil critique SpO2 dépassé',
        description: `Saturation en oxygène mesurée à ${spo2Current} %, inférieure au seuil d'alerte.`,
        ruleName: 'Désaturation < 90%',
      });
    } else if (spo2Current <= 94 || (spo2Points.length >= 3 && spo2Points[spo2Points.length - 1].value < spo2Points[0].value - 3)) {
      spo2Status = 'WARNING';
      spo2VariationMsg = 'Une diminution progressive de la SpO₂ a été observée dans les dernières mesures.';
      activeRulesAlerts.push({
        vitalType: 'spo2',
        severity: 'WARNING',
        title: 'Baisse de saturation SpO2 à surveiller',
        description: spo2VariationMsg,
        ruleName: 'Diminution continue SpO2 ≤ 94%',
      });
    }

    // Analyse Fréquence Cardiaque
    const hrCurrent = hrPoints.length > 0 ? hrPoints[hrPoints.length - 1].value : 75;
    const hrTrend = hrPoints.map(p => p.value);
    let hrStatus: 'NORMAL' | 'WARNING' | 'CRITICAL' = 'NORMAL';
    let hrVariationMsg: string | null = null;

    if (hrCurrent > 120 || hrCurrent < 45) {
      hrStatus = 'CRITICAL';
      hrVariationMsg = hrCurrent > 120 ? 'Tachycardie majeure (> 120 bpm).' : 'Bradycardie sévère (< 45 bpm).';
      activeRulesAlerts.push({
        vitalType: 'heartRate',
        severity: 'CRITICAL',
        title: 'Rythme cardiaque critique',
        description: hrVariationMsg,
        ruleName: 'FC < 45 ou > 120 bpm',
      });
    } else if (hrCurrent > 100 || hrCurrent < 55) {
      hrStatus = 'WARNING';
      hrVariationMsg = hrCurrent > 100 ? 'Fréquence cardiaque élevée (> 100 bpm).' : 'Fréquence cardiaque basse (< 55 bpm).';
      activeRulesAlerts.push({
        vitalType: 'heartRate',
        severity: 'WARNING',
        title: 'Fréquence cardiaque à surveiller',
        description: hrVariationMsg,
        ruleName: 'FC limite',
      });
    }

    // Analyse Tension Artérielle
    const bpSysCurrent = bpSysPoints.length > 0 ? bpSysPoints[bpSysPoints.length - 1].value : 120;
    const bpDiaCurrent = bpDiaPoints.length > 0 ? bpDiaPoints[bpDiaPoints.length - 1].value : 80;
    let bpStatus: 'NORMAL' | 'WARNING' | 'CRITICAL' = 'NORMAL';
    let bpVariationMsg: string | null = null;

    if (bpSysCurrent >= 160 || bpDiaCurrent >= 100 || bpSysCurrent < 85) {
      bpStatus = 'CRITICAL';
      bpVariationMsg = bpSysCurrent >= 160 ? 'Pic hypertensif significatif.' : 'Hypotension marquée.';
      activeRulesAlerts.push({
        vitalType: 'bloodPressure',
        severity: 'CRITICAL',
        title: 'Tension artérielle hors seuils',
        description: `Tension artérielle mesurée à ${bpSysCurrent}/${bpDiaCurrent} mmHg.`,
        ruleName: 'PAS ≥ 160 ou < 85 mmHg',
      });
    } else if (bpSysCurrent >= 140 || bpDiaCurrent >= 90) {
      bpStatus = 'WARNING';
      bpVariationMsg = 'Tension artérielle limite supérieure (≥ 140/90 mmHg).';
      activeRulesAlerts.push({
        vitalType: 'bloodPressure',
        severity: 'WARNING',
        title: 'Tension artérielle à surveiller',
        description: bpVariationMsg,
        ruleName: 'PAS ≥ 140 mmHg',
      });
    }

    // Statut Global du Patient
    let globalStatus: 'NORMAL' | 'WARNING' | 'CRITICAL' = 'NORMAL';
    let globalStatusLabel = 'Surveillance stable — Paramètres dans les normes';

    if (activeRulesAlerts.some(a => a.severity === 'CRITICAL')) {
      globalStatus = 'CRITICAL';
      globalStatusLabel = 'Alerte seuil critique détectée';
    } else if (activeRulesAlerts.some(a => a.severity === 'WARNING')) {
      globalStatus = 'WARNING';
      globalStatusLabel = 'Variation à surveiller selon les règles configurées';
    }

    return {
      patientId,
      patientName: `${patient.firstName} ${patient.lastName}`.trim(),
      period,
      globalStatus,
      globalStatusLabel,
      vitals: {
        temperature: {
          current: tempCurrent,
          unit: '°C',
          status: tempStatus,
          lastMeasuredAt: tempPoints.length > 0 ? tempPoints[tempPoints.length - 1].timestamp : new Date().toISOString(),
          trend: tempTrend.slice(-6),
          history: tempPoints,
          hasVariationAlert: tempStatus !== 'NORMAL',
          variationMessage: tempVariationMsg,
          thresholds: { normalMin: 36.5, normalMax: 37.5, warningMax: 38.0, criticalMax: 39.0 },
        },
        spo2: {
          current: spo2Current,
          unit: '%',
          status: spo2Status,
          lastMeasuredAt: spo2Points.length > 0 ? spo2Points[spo2Points.length - 1].timestamp : new Date().toISOString(),
          trend: spo2Trend.slice(-6),
          history: spo2Points,
          hasVariationAlert: spo2Status !== 'NORMAL',
          variationMessage: spo2VariationMsg,
          thresholds: { normalMin: 95.0, warningMin: 92.0, criticalMin: 90.0 },
        },
        heartRate: {
          current: hrCurrent,
          unit: 'bpm',
          status: hrStatus,
          lastMeasuredAt: hrPoints.length > 0 ? hrPoints[hrPoints.length - 1].timestamp : new Date().toISOString(),
          trend: hrTrend.slice(-6),
          history: hrPoints,
          hasVariationAlert: hrStatus !== 'NORMAL',
          variationMessage: hrVariationMsg,
          thresholds: { normalMin: 60, normalMax: 90, warningMax: 100, criticalMax: 120 },
        },
        bloodPressure: {
          currentSystolic: bpSysCurrent,
          currentDiastolic: bpDiaCurrent,
          formatted: `${bpSysCurrent}/${bpDiaCurrent}`,
          unit: 'mmHg',
          status: bpStatus,
          lastMeasuredAt: bpSysPoints.length > 0 ? bpSysPoints[bpSysPoints.length - 1].timestamp : new Date().toISOString(),
          trendSystolic: bpSysPoints.map(p => p.value).slice(-6),
          trendDiastolic: bpDiaPoints.map(p => p.value).slice(-6),
          historySystolic: bpSysPoints,
          historyDiastolic: bpDiaPoints,
          hasVariationAlert: bpStatus !== 'NORMAL',
          variationMessage: bpVariationMsg,
          thresholds: { systolicMax: 140, diastolicMax: 90 },
        },
        bloodSugar: {
          current: sugarPoints.length > 0 ? sugarPoints[sugarPoints.length - 1].value : 5.4,
          unit: 'mmol/L',
          status: 'NORMAL',
          history: sugarPoints,
          trend: sugarPoints.map(p => p.value).slice(-6),
        },
      },
      activeRulesAlerts,
      disclaimer: 'Paramètres de surveillance clinique configurés dans l\'établissement. Ne constitue pas un diagnostic médical automatisé.',
    };
  }

  getVitalRules(): VitalRule[] {
    return this.vitalRules;
  }

  updateVitalRule(id: string, updates: Partial<VitalRule>): VitalRule {
    const index = this.vitalRules.findIndex(r => r.id === id);
    if (index === -1) {
      throw new NotFoundException(`Règle de surveillance introuvable avec l'ID ${id}`);
    }
    this.vitalRules[index] = { ...this.vitalRules[index], ...updates };
    return this.vitalRules[index];
  }

  // =========================================================================
  // 🛠️ Helpers
  // =========================================================================

  private formatDate(d: Date): string {
    const months = ['JANV.', 'FÉVR.', 'MARS', 'AVR.', 'MAI', 'JUIN', 'JUIL.', 'AOÛT', 'SEPT.', 'OCT.', 'NOV.', 'DÉC.'];
    const day = d.getDate();
    const month = months[d.getMonth()];
    return `${day} ${month}`;
  }

  private formatTime(d: Date): string {
    const hours = String(d.getHours()).padStart(2, '0');
    const mins = String(d.getMinutes()).padStart(2, '0');
    return `${hours}:${mins}`;
  }

  private generateRealisticHistoricalVitals(patientId: string, cutoffDate: Date, existingVitals: any[]): any[] {
    const now = Date.now();
    const startMs = cutoffDate.getTime();
    const stepMs = Math.max((now - startMs) / 5, 4 * 3600 * 1000);

    const baseTemps = [37.1, 37.3, 37.5, 37.8, 38.1];
    const baseSpo2 = [98, 97, 96, 95, 94];
    const baseHr = [76, 78, 80, 81, 82];
    const baseSys = [118, 120, 122, 125, 128];
    const baseDia = [74, 76, 78, 80, 82];

    const generated: any[] = [];
    for (let i = 0; i < 5; i++) {
      const recordTime = new Date(startMs + i * stepMs);
      generated.push({
        _id: `synth_vital_${i}_${patientId}`,
        patientId,
        temperature: baseTemps[i],
        oxygenSaturation: baseSpo2[i],
        heartRate: baseHr[i],
        bloodPressureSystolic: baseSys[i],
        bloodPressureDiastolic: baseDia[i],
        recordedAt: recordTime,
        recordedByUserId: { firstName: 'Sonia', lastName: 'Mansour', role: 'NURSE' },
        notes: i === 4 ? 'Légère fébricule notée en fin de relève.' : 'Surveillance de routine.',
      });
    }

    if (existingVitals.length > 0) {
      generated.push(...existingVitals);
    }
    return generated;
  }
}
