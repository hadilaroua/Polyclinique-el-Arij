import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Patient, PatientDocument } from '../../patients/schemas/patient.schema';
import { Consultation, ConsultationDocument } from '../../consultations/schemas/consultation.schema';
import { Exam, ExamDocument, ExamStatus } from '../../exams/schemas/exam.schema';
import { VitalSign, VitalSignDocument } from '../../vital-signs/schemas/vital-sign.schema';
import { Alert, AlertDocument } from '../../alerts/schemas/alert.schema';
import { HospitalStay, HospitalStayDocument, StayStatus } from '../../hospitalization/schemas/hospital-stay.schema';
import { Appointment, AppointmentDocument } from '../../appointments/schemas/appointment.schema';
import { Doctor, DoctorDocument } from '../../doctors/schemas/doctor.schema';

@Injectable()
export class AiContextBuilderService {
  constructor(
    @InjectModel(Patient.name) private patientModel: Model<PatientDocument>,
    @InjectModel(Consultation.name) private consultationModel: Model<ConsultationDocument>,
    @InjectModel(Exam.name) private examModel: Model<ExamDocument>,
    @InjectModel(VitalSign.name) private vitalSignModel: Model<VitalSignDocument>,
    @InjectModel(Alert.name) private alertModel: Model<AlertDocument>,
    @InjectModel(HospitalStay.name) private stayModel: Model<HospitalStayDocument>,
    @InjectModel(Appointment.name) private appointmentModel: Model<AppointmentDocument>,
    @InjectModel(Doctor.name) private doctorModel: Model<DoctorDocument>,
  ) {}

  /**
   * Construit un contexte clinique complet et réel pour un patient spécifique depuis MongoDB.
   */
  async buildPatientContext(patientId: string, user: any): Promise<string> {
    let patient: any;
    if (patientId && patientId.match(/^[0-9a-fA-F]{24}$/)) {
      patient = await this.patientModel.findById(patientId).exec();
    }
    if (!patient && patientId) {
      patient = await this.patientModel.findOne({
        $or: [{ dossierNumber: patientId }, { cin: patientId }],
      }).exec();
    }
    if (!patient && patientId) {
      const cleanTerm = patientId.trim();
      const parts = cleanTerm.split(/\s+/);
      if (parts.length >= 2) {
        patient = await this.patientModel.findOne({
          $or: [
            { firstName: new RegExp(parts[0], 'i'), lastName: new RegExp(parts.slice(1).join(' '), 'i') },
            { firstName: new RegExp(parts.slice(1).join(' '), 'i'), lastName: new RegExp(parts[0], 'i') },
          ],
        }).exec();
      }
      if (!patient) {
        patient = await this.patientModel.findOne({
          $or: [
            { firstName: new RegExp(cleanTerm, 'i') },
            { lastName: new RegExp(cleanTerm, 'i') },
          ],
        }).exec();
      }
    }

    if (!patient) {
      return `Aucun patient correspondant au nom ou identifiant "${patientId}" n'a été trouvé dans la base de données de la clinique.`;
    }

    const fullName = `${patient.firstName || ''} ${patient.lastName || ''}`.trim();
    const contextParts: string[] = [];
    contextParts.push(`=== DOSSIER PATIENT INDIVIDUEL (TEMPS RÉEL MONGO DB) ===`);
    contextParts.push(`Nom et Prénom : ${fullName || 'N/A'}`);
    contextParts.push(`CIN : ${patient.cin || 'N/A'}`);
    contextParts.push(`N° Dossier : ${patient.dossierNumber || 'N/A'}`);
    contextParts.push(`Date de Naissance : ${patient.dateOfBirth ? patient.dateOfBirth : 'N/A'}`);
    contextParts.push(`Sexe : ${patient.gender || 'N/A'}`);
    contextParts.push(`Groupe Sanguin : ${patient.bloodType || 'Inconnu'}`);
    contextParts.push(`Téléphone : ${patient.phone || 'N/A'}`);
    contextParts.push(`Service / Département : ${patient.department || 'Général'}`);
    contextParts.push(`Antécédents / Maladies chroniques : ${patient.chronicDiseases?.length ? patient.chronicDiseases.join(', ') : 'Aucune'}`);
    contextParts.push(`Allergies connues : ${patient.allergies?.length ? patient.allergies.join(', ') : 'Aucune'}`);

    // Hospitalisation active
    const activeStay = await this.stayModel.findOne({ patientId: patient._id, status: StayStatus.ACTIVE }).exec();
    if (activeStay) {
      contextParts.push(`\n--- SÉJOUR HOSPITALISATION ACTIF ---`);
      contextParts.push(`Service : ${activeStay.service}`);
      contextParts.push(`Motif d'admission : ${activeStay.admissionReason || 'Non précisé'}`);
      contextParts.push(`Date d'admission : ${activeStay.admissionDate ? new Date(activeStay.admissionDate).toLocaleString('fr-FR') : 'N/A'}`);
    } else {
      contextParts.push(`\n--- SÉJOUR HOSPITALISATION : Aucun séjour actif en ce moment ---`);
    }

    // Consultations récents
    const consultations = await this.consultationModel.find({ patientId: patient._id }).sort({ createdAt: -1 }).limit(5).exec();
    if (consultations.length > 0) {
      contextParts.push(`\n--- CONSULTATIONS RÉCENTES DE CE PATIENT (${consultations.length}) ---`);
      consultations.forEach((c, idx) => {
        const dateStr = (c as any).createdAt ? new Date((c as any).createdAt).toLocaleDateString('fr-FR') : 'N/A';
        contextParts.push(`${idx + 1}. [${dateStr}] Motif: ${(c as any).reason || (c as any).motive || 'N/A'} | Diagnostic: ${(c as any).diagnostic || 'N/A'} | Prescription: ${(c as any).prescription || 'Aucune'} | Obs: ${(c as any).observations || 'N/A'}`);
      });
    } else {
      contextParts.push(`\n--- CONSULTATIONS RÉCENTES : Aucune consultation enregistrée pour ce patient ---`);
    }

    // Examens récents
    const exams = await this.examModel.find({ patientId: patient._id }).sort({ createdAt: -1 }).limit(5).exec();
    if (exams.length > 0) {
      contextParts.push(`\n--- EXAMENS ET BILANS DE CE PATIENT (${exams.length}) ---`);
      exams.forEach((e, idx) => {
        const dateStr = (e as any).createdAt ? new Date((e as any).createdAt).toLocaleDateString('fr-FR') : 'N/A';
        const resStr = e.result ? ` | Résultat: ${e.result}` : '';
        contextParts.push(`${idx + 1}. [${dateStr}] Examen: ${(e as any).examType || (e as any).type || 'N/A'} | Priorité: ${(e as any).priority || 'NORMALE'} | Statut: ${e.status}${resStr}`);
      });
    } else {
      contextParts.push(`\n--- EXAMENS DE LABORATOIRE & RADIOLOGIE : Aucun examen demandé pour ce patient ---`);
    }

    // Constantes vitales récentes
    const vitals = await this.vitalSignModel.find({ patientId: patient._id }).sort({ recordedAt: -1 }).limit(5).exec();
    if (vitals.length > 0) {
      contextParts.push(`\n--- RELEVÉS DE CONSTANTES VITALES ---`);
      vitals.forEach((v) => {
        const dateStr = v.recordedAt ? new Date(v.recordedAt).toLocaleString('fr-FR') : 'N/A';
        contextParts.push(`• ${dateStr} => T°: ${v.temperature ?? 'N/A'}°C, Tension: ${(v as any).bloodPressure || (v as any).bloodPressureSystolic ? `${(v as any).bloodPressureSystolic}/${(v as any).bloodPressureDiastolic}` : 'N/A'}, Pouls: ${v.heartRate ?? 'N/A'} bpm, SpO2: ${v.oxygenSaturation ?? 'N/A'}%`);
      });
    } else {
      contextParts.push(`\n--- CONSTANTES VITALES : Aucun relevé disponible ---`);
    }

    // Alertes non résolues
    const alerts = await this.alertModel.find({ patientId: patient._id, isResolved: false }).sort({ createdAt: -1 }).exec();
    if (alerts.length > 0) {
      contextParts.push(`\n--- ALERTES CLINIQUES ACTIVES POUR CE PATIENT (${alerts.length}) ---`);
      alerts.forEach((a) => {
        contextParts.push(`⚠️ [Niveau: ${a.level}] ${a.title} : ${a.description}`);
      });
    } else {
      contextParts.push(`\n--- ALERTES CLINIQUES : Aucune alerte active pour ce patient ---`);
    }

    return contextParts.join('\n');
  }

  private getPatientFullName(p: any): string {
    if (!p) return 'Patient';
    const fname = (p.firstName || '').toString().replace(/^undefined$/i, '').trim();
    const lname = (p.lastName || '').toString().replace(/^undefined$/i, '').trim();
    const full = `${fname} ${lname}`.trim();
    return full.length > 0 ? full : (p.dossierNumber ? `Patient (${p.dossierNumber})` : 'Patient');
  }

  /**
   * Construit un contexte clinique filtré stricte par rôle en temps réel depuis la base MongoDB.
   */
  async buildGeneralClinicalContext(user: any): Promise<string> {
    const contextParts: string[] = [];
    const userId = user._id || user.id || user.sub;
    const userRole = (user.role || 'STAFF').toUpperCase();
    contextParts.push(`Utilisateur connecté: ${user.firstName || ''} ${user.lastName || ''} (Rôle: ${userRole})`);

    // Trouver le profil Doctor si l'utilisateur est médecin
    let doctorRecord: any = null;
    if (userRole === 'DOCTOR') {
      doctorRecord = await this.doctorModel.findOne({ userId }).exec();
    }

    // --- 1. FILTRAGE RÔLE DES CONSULTATIONS ---
    let consultationsQuery: any = {};
    if (userRole === 'DOCTOR') {
      const docIds = [userId];
      if (doctorRecord?._id) docIds.push(doctorRecord._id);
      consultationsQuery = { doctorId: { $in: docIds } };
    }

    const consultations = await this.consultationModel.find(consultationsQuery).sort({ createdAt: -1 }).limit(10).exec();

    // --- 2. FILTRAGE RÔLE DES EXAMENS ---
    let examsQuery: any = {};
    if (userRole === 'DOCTOR') {
      const docIds = [userId];
      if (doctorRecord?._id) docIds.push(doctorRecord._id);
      examsQuery = { $or: [{ doctorId: { $in: docIds } }, { requestingDoctorId: { $in: docIds } }] };
    } else if (userRole === 'TECHNICIAN') {
      examsQuery = { $or: [{ status: ExamStatus.PENDING }, { technicianId: userId }] };
    }

    const exams = await this.examModel.find(examsQuery).sort({ createdAt: -1 }).limit(10).exec();

    // --- 3. FILTRAGE RÔLE DES HOSPITALISATIONS ---
    let staysQuery: any = { status: StayStatus.ACTIVE };
    if (userRole === 'DOCTOR') {
      const docIds = [userId];
      if (doctorRecord?._id) docIds.push(doctorRecord._id);
      const docService = doctorRecord?.service || user.service;
      const orConditions: any[] = [{ attendingDoctorId: { $in: docIds } }];
      if (docService) orConditions.push({ service: docService });
      staysQuery = { status: StayStatus.ACTIVE, $or: orConditions };
    } else if (userRole === 'MIDWIFE') {
      staysQuery = { status: StayStatus.ACTIVE, service: new RegExp('Gynécologie|Maternité|Obstétrique', 'i') };
    }

    const activeStays = await this.stayModel.find(staysQuery).exec();

    // --- 4. FILTRAGE RÔLE DES ALERTES ---
    let alertsQuery: any = { isResolved: false };
    if (userRole === 'DOCTOR') {
      alertsQuery = {
        isResolved: false,
        $or: [
          { targetRoles: 'DOCTOR' },
          { targetDoctorId: userId },
          ...(doctorRecord?._id ? [{ targetDoctorId: doctorRecord._id }] : []),
        ],
      };
    } else if (userRole === 'NURSE') {
      alertsQuery = { isResolved: false, targetRoles: 'NURSE' };
    } else if (userRole === 'MIDWIFE') {
      alertsQuery = { isResolved: false, targetRoles: 'MIDWIFE' };
    } else if (userRole === 'TECHNICIAN') {
      alertsQuery = { isResolved: false, targetRoles: 'TECHNICIAN' };
    }

    const activeAlerts = await this.alertModel.find(alertsQuery).sort({ createdAt: -1 }).limit(10).exec();

    // --- 5. PATIENTS AUTORISÉS / SUIVIS PAR CE SOIGNANT ---
    let patientIds: any[] = [];
    if (userRole === 'DOCTOR') {
      const patientIdSet = new Set<string>();
      consultations.forEach(c => c.patientId && patientIdSet.add(c.patientId.toString()));
      exams.forEach(e => (e as any).patientId && patientIdSet.add((e as any).patientId.toString()));
      activeStays.forEach(s => s.patientId && patientIdSet.add(s.patientId.toString()));
      patientIds = Array.from(patientIdSet);
    }

    let patients: any[] = [];
    if (userRole === 'DOCTOR' && patientIds.length > 0) {
      patients = await this.patientModel.find({ _id: { $in: patientIds } }).sort({ lastName: 1 }).exec();
    } else if (userRole === 'ADMIN' || userRole === 'NURSE') {
      patients = await this.patientModel.find({ isActive: true }).sort({ lastName: 1 }).limit(15).exec();
    } else if (userRole === 'MIDWIFE') {
      patients = await this.patientModel.find({ department: new RegExp('Gynécologie|Maternité|Obstétrique', 'i') }).limit(15).exec();
    } else {
      patients = await this.patientModel.find({ _id: { $in: patientIds } }).limit(15).exec();
    }

    // CONSTRUIRE LE TEXTE DU CONTEXTE
    contextParts.push(`\n--- PATIENTS SUIVIS / AUTORISÉS POUR CE SOIGNANT (${patients.length}) ---`);
    if (patients.length > 0) {
      patients.forEach((p, idx) => {
        const name = this.getPatientFullName(p);
        contextParts.push(`${idx + 1}. Patient: ${name} | Dossier: ${p.dossierNumber || 'N/A'} | CIN: ${p.cin || 'N/A'} | Service: ${p.department || 'Général'}`);
      });
    } else {
      contextParts.push(`Aucun patient directement sous la responsabilité de ce médecin actuellement.`);
    }

    contextParts.push(`\n--- CONSULTATIONS DE CE MÉDECIN (${consultations.length}) ---`);
    if (consultations.length > 0) {
      for (const c of consultations) {
        const p = patients.find(pat => pat._id.toString() === (c as any).patientId?.toString()) || await this.patientModel.findById((c as any).patientId).exec();
        const pName = this.getPatientFullName(p);
        contextParts.push(`• [${(c as any).createdAt ? new Date((c as any).createdAt).toLocaleDateString('fr-FR') : 'N/A'}] Patient: ${pName} | Motif: ${(c as any).reason || (c as any).motive || 'N/A'} | Diagnostic: ${(c as any).diagnostic || 'N/A'}`);
      }
    } else {
      contextParts.push(`Aucune consultation enregistrée par ce médecin.`);
    }

    const pendingExams = exams.filter(e => e.status === ExamStatus.PENDING);
    contextParts.push(`\n--- EXAMENS PRESCRITS PAR CE MÉDECIN (${exams.length} dont ${pendingExams.length} en attente) ---`);
    if (exams.length > 0) {
      for (const e of exams) {
        const p = patients.find(pat => pat._id.toString() === (e as any).patientId?.toString()) || await this.patientModel.findById((e as any).patientId).exec();
        const pName = this.getPatientFullName(p);
        const resStr = e.result ? ` | Résultat: ${e.result}` : '';
        contextParts.push(`• [Statut: ${e.status}] Examen: ${(e as any).examType || (e as any).type || 'N/A'} | Patient: ${pName}${resStr}`);
      }
    } else {
      contextParts.push(`Aucun examen prescrit par ce médecin actuellement.`);
    }

    contextParts.push(`\n--- PATIENTS HOSPITALISÉS EN CHARGE (${activeStays.length}) ---`);
    if (activeStays.length > 0) {
      for (const stay of activeStays) {
        const p = patients.find(pat => pat._id.toString() === stay.patientId.toString()) || await this.patientModel.findById(stay.patientId).exec();
        const pName = this.getPatientFullName(p);
        const admDate = stay.admissionDate ? new Date(stay.admissionDate).toLocaleDateString('fr-FR') : 'N/A';
        contextParts.push(`• ${pName} | Service: ${stay.service} | Admission: ${admDate} | Motif: ${stay.admissionReason || 'Non renseigné'}`);
      }
    } else {
      contextParts.push(`Aucune hospitalisation active sous la charge de ce médecin.`);
    }

    contextParts.push(`\n--- ALERTES CLINIQUES DE CE SERVICE/MÉDECIN (${activeAlerts.length}) ---`);
    if (activeAlerts.length > 0) {
      for (const a of activeAlerts) {
        const pId = (a as any).patientId?.toString();
        const p = pId ? (patients.find(pat => pat._id.toString() === pId) || await this.patientModel.findById(pId).exec()) : null;
        const pName = p ? this.getPatientFullName(p) : 'Patient non spécifié';
        contextParts.push(`🚨 [${a.level}] Patient: ${pName} | ${a.title} : ${a.description}`);
      }
    } else {
      contextParts.push(`Aucune alerte urgente non résolue.`);
    }

    return contextParts.join('\n');
  }
}
