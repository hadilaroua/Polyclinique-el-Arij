import {
  BadRequestException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { AlertsService } from '../alerts/alerts.service';
import { AuditLogsService } from '../audit-logs/audit-logs.service';
import { AlertLevel } from '../common/enums/alert-level.enum';
import { Role } from '../common/enums/role.enum';
import {
  AssignExamDto,
  CompleteExamDto,
  CreateExamDto,
  UpdateExamDto,
} from './dto/exam.dto';
import { Exam, ExamDocument, ExamPriority, ExamStatus } from './schemas/exam.schema';

const PATIENT_POP = {
  path: 'patientId',
  select: 'firstName lastName dossierNumber cin attendingDoctorId',
  populate: {
    path: 'attendingDoctorId',
    populate: { path: 'userId', select: 'firstName lastName email' },
  },
};
const DOCTOR_POP = { path: 'requestingDoctorId', populate: { path: 'userId', select: 'firstName lastName email' } };
const TECH_POP = { path: 'assignedTechnicianId', populate: { path: 'userId', select: 'firstName lastName email' } };

@Injectable()
export class ExamsService {
  constructor(
    @InjectModel(Exam.name) private examModel: Model<ExamDocument>,
    @Optional() private alertsService?: AlertsService,
    @Optional() private auditLogsService?: AuditLogsService,
  ) {}

  async create(dto: CreateExamDto): Promise<ExamDocument> {
    const exam = new this.examModel(dto);
    const saved = await exam.save();
    const populated = await saved
      .populate(DOCTOR_POP)
      .then((e) => e.populate(PATIENT_POP));

    // Audit Log: Demande d'examen
    if (this.auditLogsService) {
      const patient: any = populated.patientId;
      const doctor: any = populated.requestingDoctorId;
      const docName = doctor?.userId ? `Dr. ${doctor.userId.firstName || ''} ${doctor.userId.lastName || ''}`.trim() : 'Médecin';
      const patName = patient ? `${patient.firstName || ''} ${patient.lastName || ''}`.trim() : 'Patient';

      this.auditLogsService.recordAction({
        action: 'DEMANDE_EXAMEN',
        category: 'EXAMEN',
        actorId: dto.requestingDoctorId || saved._id.toString(),
        actorName: docName,
        actorRole: Role.DOCTOR,
        patientId: dto.patientId,
        patientName: patName,
        patientDossier: patient?.dossierNumber || '',
        entityId: saved._id.toString(),
        targetEntity: 'Exam',
        details: `Prescription examen : ${dto.examType} (Priorité : ${dto.priority}). Service : ${dto.service || 'Non spécifié'}`,
      }).catch(() => {});
    }

    return populated;
  }

  async findAll(filters: {
    patientId?: string;
    doctorId?: string;
    technicianId?: string;
    service?: string;
    status?: ExamStatus;
    priority?: string;
  }): Promise<ExamDocument[]> {
    const filter: Record<string, any> = {};
    if (filters.patientId) filter.patientId = filters.patientId;
    if (filters.doctorId) filter.requestingDoctorId = filters.doctorId;
    if (filters.technicianId) filter.assignedTechnicianId = filters.technicianId;
    if (filters.service) filter.service = new RegExp(filters.service, 'i');
    if (filters.status) filter.status = filters.status;
    if (filters.priority) filter.priority = filters.priority;

    return this.examModel
      .find(filter)
      .populate(PATIENT_POP)
      .populate(DOCTOR_POP)
      .populate(TECH_POP)
      .sort({ priority: 1, createdAt: -1 })
      .exec();
  }

  async findById(id: string): Promise<ExamDocument> {
    const exam = await this.examModel
      .findById(id)
      .populate(PATIENT_POP)
      .populate(DOCTOR_POP)
      .populate(TECH_POP)
      .exec();
    if (!exam) {
      throw new NotFoundException(`Examen introuvable avec l'ID : ${id}`);
    }
    return exam;
  }

  /**
   * Assigner un technicien et passer en IN_PROGRESS
   */
  async assign(id: string, dto: AssignExamDto): Promise<ExamDocument> {
    const exam = await this.findById(id);
    if (exam.status !== ExamStatus.PENDING) {
      throw new BadRequestException(`Impossible d'assigner un examen avec le statut ${exam.status}`);
    }
    const updated = await this.examModel
      .findByIdAndUpdate(
        id,
        {
          assignedTechnicianId: dto.technicianId,
          status: ExamStatus.IN_PROGRESS,
          startedAt: new Date(),
        },
        { new: true },
      )
      .populate(PATIENT_POP)
      .populate(TECH_POP)
      .exec();
    if (!updated) throw new NotFoundException(`Examen introuvable avec l'ID : ${id}`);
    return updated;
  }

  /**
   * Compléter l'examen avec le résultat
   */
  async complete(id: string, dto: CompleteExamDto): Promise<ExamDocument> {
    const exam = await this.findById(id);
    if (exam.status !== ExamStatus.IN_PROGRESS) {
      throw new BadRequestException(`L'examen doit être EN COURS pour être complété`);
    }
    const updated = await this.examModel
      .findByIdAndUpdate(
        id,
        {
          result: dto.result,
          technicalNotes: dto.technicalNotes || '',
          resultDocumentUrl: dto.resultDocumentUrl || '',
          status: ExamStatus.COMPLETED,
          completedAt: new Date(),
        },
        { new: true },
      )
      .populate(PATIENT_POP)
      .populate(DOCTOR_POP)
      .populate(TECH_POP)
      .exec();
    if (!updated) throw new NotFoundException(`Examen introuvable avec l'ID : ${id}`);

    // Créer une alerte médicale ciblée pour notifier le médecin prescripteur
    const patient: any = updated.patientId;
    const patName = patient ? `${patient.firstName || ''} ${patient.lastName || ''}`.trim() : 'Patient';
    const tech: any = updated.assignedTechnicianId;
    const techName = tech?.userId ? `${tech.userId.firstName || ''} ${tech.userId.lastName || ''}`.trim() : 'Technicien';

    if (this.alertsService) {
      const isUrgent = updated.priority === ExamPriority.URGENT || updated.priority === ExamPriority.HIGH;
      const creatorId = tech?.userId?._id
        ? tech.userId._id.toString()
        : (updated.requestingDoctorId as any)?._id?.toString() || '000000000000000000000000';
      const requestingDoctorUser = (updated.requestingDoctorId as any)?.userId;
      const targetDoctorUserId = requestingDoctorUser?._id?.toString() || (updated.requestingDoctorId as any)?._id?.toString();

      this.alertsService
        .create(
          {
            patientId: patient?._id ? patient._id.toString() : undefined,
            targetDoctorId: targetDoctorUserId,
            level: isUrgent ? AlertLevel.WARNING : AlertLevel.INFO,
            title: `Résultat d'examen disponible : ${updated.examType}`,
            description: `L'examen (${updated.examType}) pour ${patName} a été validé par le plateau technique. Résultat : ${dto.result}`,
            category: 'Examen Médical',
            targetRoles: [Role.DOCTOR],
          },
          creatorId,
        )
        .catch(() => {});
    }

    // Journal d'Audit Clinique
    if (this.auditLogsService && tech?.userId?._id) {
      this.auditLogsService.recordAction({
        action: 'VALIDATION_EXAMEN',
        category: 'EXAMEN',
        actorId: tech.userId._id.toString(),
        actorName: techName,
        actorRole: Role.TECHNICIAN,
        patientId: patient?._id ? patient._id.toString() : undefined,
        patientName: patName,
        patientDossier: patient?.dossierNumber || '',
        entityId: updated._id.toString(),
        targetEntity: 'Exam',
        details: `Examen ${updated.examType} validé. Résultat : ${dto.result}`,
        metadata: {
          hasResultDocument: Boolean(dto.resultDocumentUrl),
        },
      }).catch(() => {});
    }

    return updated;
  }

  /**
   * Annuler un examen
   */
  async cancel(id: string, reason: string): Promise<ExamDocument> {
    const exam = await this.findById(id);
    if (exam.status === ExamStatus.COMPLETED) {
      throw new BadRequestException('Un examen complété ne peut pas être annulé');
    }
    const updated = await this.examModel
      .findByIdAndUpdate(
        id,
        { status: ExamStatus.CANCELLED, cancellationReason: reason },
        { new: true },
      )
      .exec();
    if (!updated) throw new NotFoundException(`Examen introuvable avec l'ID : ${id}`);
    return updated;
  }

  async update(id: string, dto: UpdateExamDto): Promise<ExamDocument> {
    const exam = await this.examModel
      .findByIdAndUpdate(id, dto, { new: true })
      .populate(PATIENT_POP)
      .exec();
    if (!exam) throw new NotFoundException(`Examen introuvable avec l'ID : ${id}`);
    return exam;
  }

  async remove(id: string): Promise<{ message: string }> {
    const exam = await this.examModel.findByIdAndDelete(id).exec();
    if (!exam) throw new NotFoundException(`Examen introuvable avec l'ID : ${id}`);
    return { message: 'Demande d\'examen supprimée avec succès' };
  }

  async count(filter: Record<string, any> = {}): Promise<number> {
    return this.examModel.countDocuments(filter).exec();
  }
}
