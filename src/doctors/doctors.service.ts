import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  CreateDoctorDto,
  ScheduleSlotDto,
  UpdateDoctorDto,
} from './dto/doctor.dto';
import { Doctor, DoctorDocument } from './schemas/doctor.schema';

@Injectable()
export class DoctorsService {
  constructor(
    @InjectModel(Doctor.name) private doctorModel: Model<DoctorDocument>,
  ) {}

  async create(createDoctorDto: CreateDoctorDto): Promise<DoctorDocument> {
    const existing = await this.doctorModel.findOne({
      $or: [
        { userId: createDoctorDto.userId },
        { licenseNumber: createDoctorDto.licenseNumber },
      ],
    });

    if (existing) {
      throw new ConflictException(
        'Un médecin existe déjà avec cet utilisateur ou ce numéro d’ordre',
      );
    }

    const doctor = new this.doctorModel(createDoctorDto);
    return (await doctor.save()).populate('userId', '-password');
  }

  async findAll(query?: {
    specialty?: string;
    service?: string;
    isAvailable?: boolean;
  }): Promise<DoctorDocument[]> {
    const filter: Record<string, any> = {};

    if (query?.specialty) {
      filter.specialty = new RegExp(query.specialty.trim(), 'i');
    }
    if (query?.service) {
      filter.service = new RegExp(query.service.trim(), 'i');
    }
    if (typeof query?.isAvailable === 'boolean') {
      filter.isAvailable = query.isAvailable;
    }

    return this.doctorModel
      .find(filter)
      .populate('userId', '-password')
      .sort({ createdAt: -1 })
      .exec();
  }

  async findById(id: string): Promise<DoctorDocument> {
    const doctor = await this.doctorModel
      .findById(id)
      .populate('userId', '-password')
      .exec();

    if (!doctor) {
      throw new NotFoundException(`Médecin introuvable avec l'ID : ${id}`);
    }
    return doctor;
  }

  async findByUserId(userId: string): Promise<DoctorDocument | null> {
    return this.doctorModel
      .findOne({ userId })
      .populate('userId', '-password')
      .exec();
  }

  async update(
    id: string,
    updateDoctorDto: UpdateDoctorDto,
  ): Promise<DoctorDocument> {
    const doctor = await this.doctorModel
      .findByIdAndUpdate(id, updateDoctorDto, { new: true })
      .populate('userId', '-password')
      .exec();

    if (!doctor) {
      throw new NotFoundException(`Médecin introuvable avec l'ID : ${id}`);
    }
    return doctor;
  }

  async updateSchedule(
    id: string,
    schedules: ScheduleSlotDto[],
  ): Promise<DoctorDocument> {
    const doctor = await this.doctorModel
      .findByIdAndUpdate(id, { schedules }, { new: true })
      .populate('userId', '-password')
      .exec();

    if (!doctor) {
      throw new NotFoundException(`Médecin introuvable avec l'ID : ${id}`);
    }
    return doctor;
  }

  async remove(id: string): Promise<{ message: string }> {
    const doctor = await this.doctorModel.findByIdAndDelete(id).exec();
    if (!doctor) {
      throw new NotFoundException(`Médecin introuvable avec l'ID : ${id}`);
    }
    return { message: 'Profil médecin supprimé avec succès' };
  }

  async count(): Promise<number> {
    return this.doctorModel.countDocuments().exec();
  }

  async removeByUserId(userId: string): Promise<void> {
    await this.doctorModel.deleteOne({ userId }).exec();
  }
}
