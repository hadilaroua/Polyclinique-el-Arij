import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { AppointmentStatus } from '../common/enums/appointment-status.enum';
import { Role } from '../common/enums/role.enum';
import { DoctorsService } from '../doctors/doctors.service';
import { PatientsService } from '../patients/patients.service';
import {
  CreateAppointmentDto,
  UpdateAppointmentStatusDto,
} from './dto/appointment.dto';
import {
  Appointment,
  AppointmentDocument,
} from './schemas/appointment.schema';

@Injectable()
export class AppointmentsService {
  constructor(
    @InjectModel(Appointment.name)
    private appointmentModel: Model<AppointmentDocument>,
    private readonly patientsService: PatientsService,
    private readonly doctorsService: DoctorsService,
  ) {}

  async create(
    createDto: CreateAppointmentDto,
    currentUser: { id: string; role: Role },
  ): Promise<AppointmentDocument> {
    let patientId = createDto.patientId;

    // Si l'utilisateur est un patient, on lie automatiquement à son profil
    if (currentUser.role === Role.PATIENT) {
      const patient = await this.patientsService.findByUserId(currentUser.id);
      if (!patient) {
        throw new BadRequestException('Profil patient introuvable');
      }
      patientId = patient._id.toString();
    }

    if (!patientId) {
      throw new BadRequestException('L’identifiant du patient est requis');
    }

    // Vérifier l'existence du médecin
    const doctor = await this.doctorsService.findById(createDto.doctorId);
    if (!doctor) {
      throw new NotFoundException('Médecin introuvable');
    }

    // Vérifier l'absence de conflit sur le même créneau horaire
    const existingAppointment = await this.appointmentModel.findOne({
      doctorId: new Types.ObjectId(createDto.doctorId),
      date: createDto.date,
      timeSlot: createDto.timeSlot,
      status: { $ne: AppointmentStatus.CANCELLED },
    });

    if (existingAppointment) {
      throw new ConflictException(
        `Le créneau ${createDto.timeSlot} du ${createDto.date} est déjà réservé pour ce médecin`,
      );
    }

    const appointment = new this.appointmentModel({
      patientId: new Types.ObjectId(patientId),
      doctorId: new Types.ObjectId(createDto.doctorId),
      date: createDto.date,
      timeSlot: createDto.timeSlot,
      reason: createDto.reason,
      status: AppointmentStatus.PENDING,
    });

    return (await appointment.save()).populate([
      {
        path: 'patientId',
        populate: { path: 'userId', select: 'firstName lastName email phone' },
      },
      {
        path: 'doctorId',
        populate: { path: 'userId', select: 'firstName lastName email phone' },
      },
    ]);
  }

  async findAll(query?: {
    patientId?: string;
    doctorId?: string;
    status?: AppointmentStatus;
    date?: string;
  }): Promise<AppointmentDocument[]> {
    const filter: Record<string, any> = {};

    if (query?.patientId) {
      filter.patientId = new Types.ObjectId(query.patientId);
    }
    if (query?.doctorId) {
      filter.doctorId = new Types.ObjectId(query.doctorId);
    }
    if (query?.status) {
      filter.status = query.status;
    }
    if (query?.date) {
      filter.date = query.date;
    }

    return this.appointmentModel
      .find(filter)
      .populate([
        {
          path: 'patientId',
          populate: { path: 'userId', select: 'firstName lastName email phone' },
        },
        {
          path: 'doctorId',
          populate: { path: 'userId', select: 'firstName lastName email phone' },
        },
      ])
      .sort({ date: -1, timeSlot: -1 })
      .exec();
  }

  async findForCurrentUser(currentUser: {
    id: string;
    role: Role;
  }): Promise<AppointmentDocument[]> {
    if (currentUser.role === Role.ADMIN || currentUser.role === Role.NURSE) {
      return this.findAll();
    }

    if (currentUser.role === Role.PATIENT) {
      const patient = await this.patientsService.findByUserId(currentUser.id);
      if (!patient) return [];
      return this.findAll({ patientId: patient._id.toString() });
    }

    if (currentUser.role === Role.DOCTOR) {
      const doctor = await this.doctorsService.findByUserId(currentUser.id);
      if (!doctor) return [];
      return this.findAll({ doctorId: doctor._id.toString() });
    }

    return [];
  }

  async findById(id: string): Promise<AppointmentDocument> {
    const appointment = await this.appointmentModel
      .findById(id)
      .populate([
        {
          path: 'patientId',
          populate: { path: 'userId', select: 'firstName lastName email phone' },
        },
        {
          path: 'doctorId',
          populate: { path: 'userId', select: 'firstName lastName email phone' },
        },
      ])
      .exec();

    if (!appointment) {
      throw new NotFoundException(`Rendez-vous introuvable avec l'ID ${id}`);
    }
    return appointment;
  }

  async updateStatus(
    id: string,
    updateDto: UpdateAppointmentStatusDto,
    currentUser: { id: string; role: Role },
  ): Promise<AppointmentDocument> {
    const appointment = await this.findById(id);

    // Contrôle d'accès : un patient ne peut qu'annuler son propre rdv
    if (currentUser.role === Role.PATIENT) {
      const patient = await this.patientsService.findByUserId(currentUser.id);
      if (
        !patient ||
        appointment.patientId._id.toString() !== patient._id.toString()
      ) {
        throw new ForbiddenException('Action non autorisée sur ce rendez-vous');
      }
      if (updateDto.status !== AppointmentStatus.CANCELLED) {
        throw new ForbiddenException('Le patient ne peut que demander l’annulation');
      }
    }

    appointment.status = updateDto.status;
    if (updateDto.notes) appointment.notes = updateDto.notes;
    if (updateDto.cancellationReason) {
      appointment.cancellationReason = updateDto.cancellationReason;
    }

    return appointment.save();
  }

  async cancel(
    id: string,
    reason: string,
    currentUser: { id: string; role: Role },
  ): Promise<AppointmentDocument> {
    return this.updateStatus(
      id,
      {
        status: AppointmentStatus.CANCELLED,
        cancellationReason: reason || 'Annulé par l’utilisateur',
      },
      currentUser,
    );
  }

  async count(filter = {}): Promise<number> {
    return this.appointmentModel.countDocuments(filter).exec();
  }
}
