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

  async findAll(patientId?: string, doctorId?: string): Promise<ConsultationDocument[]> {
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
