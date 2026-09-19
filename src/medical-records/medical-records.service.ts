import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  ConsultationEntryDto,
  CreateMedicalRecordDto,
  TreatmentItemDto,
  UpdateMedicalRecordDto,
} from './dto/medical-record.dto';
import {
  MedicalRecord,
  MedicalRecordDocument,
} from './schemas/medical-record.schema';

@Injectable()
export class MedicalRecordsService {
  constructor(
    @InjectModel(MedicalRecord.name)
    private recordModel: Model<MedicalRecordDocument>,
  ) {}

  async create(
    createDto: CreateMedicalRecordDto,
  ): Promise<MedicalRecordDocument> {
    const existing = await this.recordModel.findOne({
      patientId: createDto.patientId,
    });
    if (existing) {
      throw new BadRequestException('Un dossier médical existe déjà pour ce patient');
    }

    const record = new this.recordModel(createDto);
    return record.save();
  }

  async findByPatientId(patientId: string): Promise<MedicalRecordDocument> {
    let record = await this.recordModel
      .findOne({ patientId })
      .populate('patientId')
      .exec();

    // S'il n'existe pas encore, on l'initialise à vide pour le patient
    if (!record) {
      record = await this.recordModel.create({
        patientId,
        allergies: [],
        treatments: [],
        consultations: [],
        examinations: [],
      });
    }
    return record;
  }

  async update(
    patientId: string,
    updateDto: UpdateMedicalRecordDto,
  ): Promise<MedicalRecordDocument> {
    const updated = await this.recordModel
      .findOneAndUpdate({ patientId }, updateDto, { new: true, upsert: true })
      .exec();
    return updated;
  }

  async addConsultation(
    patientId: string,
    consultationDto: ConsultationEntryDto,
  ): Promise<MedicalRecordDocument> {
    const record = await this.findByPatientId(patientId);
    record.consultations.unshift({
      ...consultationDto,
      date: consultationDto.date || new Date().toISOString(),
      doctorSpecialty: consultationDto.doctorSpecialty || 'Médecine Générale',
      prescription: consultationDto.prescription || '',
      observations: consultationDto.observations || '',
    });
    return record.save();
  }

  async addTreatment(
    patientId: string,
    treatmentDto: TreatmentItemDto,
  ): Promise<MedicalRecordDocument> {
    const record = await this.findByPatientId(patientId);
    record.treatments.unshift({
      ...treatmentDto,
      frequency: treatmentDto.frequency || 'Quotidien',
      startDate: treatmentDto.startDate || new Date().toISOString(),
      endDate: treatmentDto.endDate || undefined,
      prescribingDoctor: treatmentDto.prescribingDoctor || '',
    });
    return record.save();
  }
}
