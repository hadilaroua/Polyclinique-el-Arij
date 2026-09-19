import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { QrCodeService } from '../qr-code/qr-code.service';
import { User, UserDocument } from '../users/schemas/user.schema';
import { CreatePatientDto } from './dto/create-patient.dto';
import { UpdatePatientDto } from './dto/update-patient.dto';
import { Patient, PatientDocument } from './schemas/patient.schema';

@Injectable()
export class PatientsService implements OnModuleInit {
  constructor(
    @InjectModel(Patient.name) private patientModel: Model<PatientDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private readonly qrCodeService: QrCodeService,
  ) {}

  async onModuleInit() {
    // Liaison automatique des données de démonstration avec l'équipe soignante
    try {
      const doctor = await this.userModel.findOne({ email: 'dr.karima@arij.tn' });
      const midwife = await this.userModel.findOne({ email: 'fatma.sagefemme@arij.tn' });
      const nurse = await this.userModel.findOne({ email: 'sonia.infirmiere@arij.tn' });

      if (doctor && midwife && nurse) {
        // Assigner Dr. Karima (Gynéco), Fatma Zahra (Sage-femme) et Sonia (Infirmière) aux patientes de maternité
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
   * Génère automatiquement le numéro de dossier et le QR code.
   */
  async create(createPatientDto: CreatePatientDto): Promise<PatientDocument> {
    // Vérification CIN unique
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

    // Génération automatique du numéro de dossier
    const count = await this.patientModel.countDocuments();
    const currentYear = new Date().getFullYear();
    const dossierNumber = `ARIJ-${currentYear}-${String(count + 1).padStart(4, '0')}`;

    // Génération du QR code
    const qrCodeToken = `QR_${Date.now()}_${Math.random().toString(36).substring(2, 9).toUpperCase()}`;
    let qrCodeImage = '';
    try {
      qrCodeImage = await this.qrCodeService.generateQrCodeDataUrl(
        qrCodeToken,
        dossierNumber,
        qrCodeToken,
      );
    } catch {
      // QR code non bloquant
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

    return (await patient.save()).populate([
      { path: 'attendingDoctorId', select: 'firstName lastName email role' },
      { path: 'assignedMidwifeId', select: 'firstName lastName email role' },
      { path: 'assignedNurseId', select: 'firstName lastName email role' },
    ]);
  }

  /**
   * Liste les patients avec recherche multi-critères et filtres d'équipe
   */
  async findAll(
    search?: string,
    onlyActive = false,
    options?: {
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

    if (options?.department && options.department !== 'ALL') {
      query.department = new RegExp(options.department, 'i');
    }

    if (options?.attendingDoctorId) {
      query.attendingDoctorId = new Types.ObjectId(options.attendingDoctorId);
    }

    if (options?.assignedMidwifeId) {
      query.assignedMidwifeId = new Types.ObjectId(options.assignedMidwifeId);
    }

    if (options?.assignedNurseId) {
      query.assignedNurseId = new Types.ObjectId(options.assignedNurseId);
    }

    if (search && search.trim() !== '') {
      const regex = new RegExp(search.trim(), 'i');
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

  /**
   * Recherche par userId (V2 — patient avec compte)
   */
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

  /**
   * Suppression logique (désactivation) — préserve les données médicales
   */
  async deactivate(id: string): Promise<PatientDocument> {
    return this.update(id, { isActive: false });
  }

  /**
   * Suppression physique — uniquement si aucun dossier associé (Admin only)
   */
  async remove(id: string): Promise<{ message: string }> {
    const patient = await this.findById(id);
    await this.patientModel.findByIdAndDelete(id).exec();
    return {
      message: `Patient ${patient.firstName} ${patient.lastName} (N° ${patient.dossierNumber}) supprimé`,
    };
  }

  /**
   * V1 compat — appelé depuis users.service lors de la suppression d'un User V2
   */
  async removeByUserId(userId: string): Promise<void> {
    await this.patientModel.updateOne({ userId }, { userId: null }).exec();
  }
}
