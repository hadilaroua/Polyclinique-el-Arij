import { Injectable, NotFoundException, Optional } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { AuditLogsService } from '../audit-logs/audit-logs.service';
import { Role } from '../common/enums/role.enum';
import { CreateConsultationDto, UpdateConsultationDto } from './dto/consultation.dto';
import { Consultation, ConsultationDocument } from './schemas/consultation.schema';

@Injectable()
export class ConsultationsService {
  constructor(
    @InjectModel(Consultation.name) private consultationModel: Model<ConsultationDocument>,
    @Optional() private auditLogsService?: AuditLogsService,
  ) {}

  async create(dto: CreateConsultationDto): Promise<ConsultationDocument> {
    const consultation = new this.consultationModel(dto);
    const saved = await consultation.save();
    const populated = await saved
      .populate('patientId', 'firstName lastName dossierNumber cin')
      .then((c) => c.populate('doctorId', 'firstName lastName email role cin avatarUrl'));

    // Enregistrement dans le Journal d'Audit Clinique
    if (this.auditLogsService) {
      const patient: any = populated.patientId;
      const doctor: any = populated.doctorId;
      const docName = doctor ? `Dr. ${doctor.firstName || ''} ${doctor.lastName || ''}`.trim() : 'Médecin';
      const patName = patient ? `${patient.firstName || ''} ${patient.lastName || ''}`.trim() : 'Patient';
      const patDossier = patient?.dossierNumber || '';

      this.auditLogsService.recordAction({
        action: 'CREATION_CONSULTATION',
        category: 'CONSULTATION',
        actorId: dto.doctorId,
        actorName: docName,
        actorRole: Role.DOCTOR,
        patientId: dto.patientId,
        patientName: patName,
        patientDossier: patDossier,
        entityId: saved._id.toString(),
        targetEntity: 'Consultation',
        details: `Consultation réalisée. Motif : ${dto.motive}. Diagnostic : ${dto.diagnostic}`,
        metadata: {
          hasPrescriptionItems: Boolean(dto.prescriptionItems && dto.prescriptionItems.length > 0),
          hasAttachments: Boolean(dto.attachments && dto.attachments.length > 0),
        },
      }).catch(() => {});
    }

    return populated;
  }

  async seedDefaultsIfEmpty(): Promise<void> {
    try {
      const count = await this.consultationModel.countDocuments().exec();
      if (count === 0) {
        const defaults = [
          {
            _id: 'consult_chirurgie_01',
            patientId: 'pat_chirurgie_01',
            patientName: 'Amine Khelifi',
            doctorId: 'doc_chirurgie',
            doctorName: 'Dr. Karima Trabelsi',
            date: '2026-05-26',
            motive: 'Consultation - Suivi Post-Opératoire Cholécystectomie',
            reason: 'Consultation - Suivi Post-Opératoire Cholécystectomie',
            diagnostic: 'Post-opératoire J+2 cholécystectomie sous cœlioscopie. Évolution clinique très favorable.',
            diagnosis: 'Post-opératoire J+2 cholécystectomie sous cœlioscopie.',
            clinicalExam: 'Abdomen souple, cicatrices de trocarts propres sans signe de surinfection. Apyrexie à 36.8°C.',
            prescription: 'Paracétamol 1g (1 cp 3x/jour si douleur) - Spasfon 80mg (1 cp 3x/jour)',
            treatmentPlan: 'Surveillance des constantes, réfection du pansement et reprise progressive de l\'alimentation.',
            prescriptionItems: [
              { medicine: 'Paracétamol 1g', posology: '1 comprimé 3 fois par jour' },
              { medicine: 'Spasfon 80mg', posology: '1 comprimé 3 fois par jour' }
            ],
            prescriptions: [
              { medicine: 'Paracétamol 1g', posology: '1 comprimé 3 fois par jour' },
              { medicine: 'Spasfon 80mg', posology: '1 comprimé 3 fois par jour' }
            ],
          },
          {
            _id: 'consult_maternite_02',
            patientId: 'pat_maternite_02',
            patientName: 'Sarra Ben Mahmoud',
            doctorId: 'doc_maternite',
            doctorName: 'Dr. Karima Trabelsi',
            date: '2026-05-26',
            motive: 'Consultation Prénatale T3 & Bilan Obstétrique',
            reason: 'Consultation Prénatale T3 & Bilan Obstétrique',
            diagnostic: 'Grossesse mono-fœtale 36 SA évolutive. Hauteur utérine conforme, BCF réguliers.',
            diagnosis: 'Grossesse 36 SA évolutive.',
            clinicalExam: 'Bruits du cœur fœtaux réguliers à 142 bpm. Pression artérielle maternelle 115/75 mmHg.',
            prescription: 'Fer + Acide Folique 1 cp/jour, Magne B6 2 cps/jour.',
            treatmentPlan: 'Programmation échographie T3 et bilan d\'anesthesie péridurale.',
            prescriptionItems: [
              { medicine: 'Fer + Acide Folique', posology: '1 comprimé par jour le matin' },
              { medicine: 'Magne B6', posology: '2 comprimés par jour' }
            ],
            prescriptions: [
              { medicine: 'Fer + Acide Folique', posology: '1 comprimé par jour le matin' },
              { medicine: 'Magne B6', posology: '2 comprimés par jour' }
            ],
          },
          {
            _id: 'consult_cardio_03',
            patientId: 'pat_cardio_03',
            patientName: 'Mohamed Trabelsi',
            doctorId: 'doc_cardio',
            doctorName: 'Dr. Karima Trabelsi',
            date: '2026-05-25',
            motive: 'Consultation Cardiologie & Évaluation Post-Stent',
            reason: 'Consultation Cardiologie & Évaluation Post-Stent',
            diagnostic: 'Suivi angioplastie coronaire. Stabilité hémodynamique et tolérance clinique satisfaisante.',
            diagnosis: 'Insuffisance coronarienne stabilisée.',
            clinicalExam: 'Auscultation cardiaque : bruits réguliers sans souffle. PA : 128/82 mmHg. FC : 68 bpm.',
            prescription: 'Kardegic 75mg (1 sachet/jour) - Tahor 20mg (1 cp le soir)',
            treatmentPlan: 'ECG de contrôle dans 1 mois et épreuve d\'effort à 3 mois.',
            prescriptionItems: [
              { medicine: 'Kardegic 75mg', posology: '1 sachet au milieu du repas' },
              { medicine: 'Tahor 20mg', posology: '1 comprimé le soir' }
            ],
            prescriptions: [
              { medicine: 'Kardegic 75mg', posology: '1 sachet au milieu du repas' },
              { medicine: 'Tahor 20mg', posology: '1 comprimé le soir' }
            ],
          },
          {
            _id: 'consult_pediatrie_04',
            patientId: 'pat_pediatrie_04',
            patientName: 'Youssef Gharbi',
            doctorId: 'doc_pediatrie',
            doctorName: 'Dr. Youssef Mahfoudh',
            date: '2026-05-24',
            motive: 'Consultation Pédiatrique - Contrôle Asthme du Nourrisson',
            reason: 'Consultation Pédiatrique - Contrôle Asthme du Nourrisson',
            diagnostic: 'Bronchiolite aiguë en phase de résolution. Râles sibilants nettement diminués.',
            diagnosis: 'Bronchiolite nourrisson en amélioration.',
            clinicalExam: 'Eupneique au repos. Fréquence respiratoire 28/min. SpO2 98% en air ambiant.',
            prescription: 'Ventoline 100µg (2 bouffées via chambre d\'inhalation 4x/jour)',
            treatmentPlan: 'Continuer les lavages nasaux multiquotidiens.',
            prescriptionItems: [
              { medicine: 'Ventoline 100µg Inhalateur', posology: '2 bouffées 4x/jour' }
            ],
            prescriptions: [
              { medicine: 'Ventoline 100µg Inhalateur', posology: '2 bouffées 4x/jour' }
            ],
          },
          {
            _id: 'consult_pma_05',
            patientId: 'pat_pma_05',
            patientName: 'Nour Ben Salem',
            doctorId: 'doc_pma',
            doctorName: 'Dr. Karima Trabelsi',
            date: '2026-05-23',
            motive: 'Consultation Suivi Protocole PMA & Monitorage Ovulation',
            reason: 'Consultation Suivi Protocole PMA & Monitorage Ovulation',
            diagnostic: 'Monitorage folliculaire J10. 2 follicules dominants à droite (17mm et 15mm).',
            diagnosis: 'Réponse folliculaire adéquate sous stimulation.',
            clinicalExam: 'Endomètre à 8.5mm, aspect en triple feuillet idéal.',
            prescription: 'Ovitrelle 250µg (1 injection sous-cutanée le soir à 22h précises)',
            treatmentPlan: 'Déclenchement ce soir et insémination à H36.',
            prescriptionItems: [
              { medicine: 'Ovitrelle 250µg Stylo', posology: '1 injection SC à 22h00' }
            ],
            prescriptions: [
              { medicine: 'Ovitrelle 250µg Stylo', posology: '1 injection SC à 22h00' }
            ],
          }
        ];
        await this.consultationModel.insertMany(defaults);
      }
    } catch (_) {}
  }

  async findAll(patientId?: string, doctorId?: string): Promise<ConsultationDocument[]> {
    await this.seedDefaultsIfEmpty();
    const filter: Record<string, any> = {};
    if (patientId) filter.patientId = patientId;
    if (doctorId) filter.doctorId = doctorId;

    return this.consultationModel
      .find(filter)
      .populate('patientId', 'firstName lastName dossierNumber cin phone')
      .populate('doctorId', 'firstName lastName email role cin avatarUrl phone')
      .sort({ date: -1, createdAt: -1 })
      .exec();
  }

  async findById(id: string): Promise<ConsultationDocument> {
    const consultation = await this.consultationModel
      .findById(id)
      .populate('patientId', 'firstName lastName dossierNumber cin bloodType allergies phone')
      .populate('doctorId', 'firstName lastName email role cin avatarUrl phone')
      .exec();
    if (!consultation) {
      throw new NotFoundException(`Consultation introuvable avec l'ID : ${id}`);
    }
    return consultation;
  }

  async findByPatient(patientId: string): Promise<ConsultationDocument[]> {
    return this.consultationModel
      .find({ patientId })
      .populate('doctorId', 'firstName lastName email role cin avatarUrl phone')
      .sort({ date: -1 })
      .exec();
  }

  async findByDoctor(doctorId: string, date?: string): Promise<ConsultationDocument[]> {
    const filter: Record<string, any> = { doctorId };
    if (date) filter.date = date;
    return this.consultationModel
      .find(filter)
      .populate('patientId', 'firstName lastName dossierNumber cin phone')
      .populate('doctorId', 'firstName lastName email role cin avatarUrl phone')
      .sort({ date: -1 })
      .exec();
  }

  async update(id: string, dto: UpdateConsultationDto): Promise<ConsultationDocument> {
    const consultation = await this.consultationModel
      .findByIdAndUpdate(id, dto, { new: true })
      .populate('patientId', 'firstName lastName dossierNumber')
      .exec();
    if (!consultation) {
      throw new NotFoundException(`Consultation introuvable avec l'ID : ${id}`);
    }
    return consultation;
  }

  async remove(id: string): Promise<{ message: string }> {
    const consultation = await this.consultationModel.findByIdAndDelete(id).exec();
    if (!consultation) {
      throw new NotFoundException(`Consultation introuvable avec l'ID : ${id}`);
    }
    return { message: 'Consultation supprimée avec succès' };
  }

  async count(filter: Record<string, any> = {}): Promise<number> {
    return this.consultationModel.countDocuments(filter).exec();
  }
}
