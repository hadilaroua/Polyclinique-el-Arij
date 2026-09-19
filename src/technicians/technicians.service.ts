import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { CreateTechnicianDto, UpdateTechnicianDto } from './dto/technician.dto';
import { Technician, TechnicianDocument } from './schemas/technician.schema';

@Injectable()
export class TechniciansService {
  constructor(
    @InjectModel(Technician.name) private technicianModel: Model<TechnicianDocument>,
  ) {}

  async create(dto: CreateTechnicianDto): Promise<TechnicianDocument> {
    const existing = await this.technicianModel.findOne({ userId: dto.userId });
    if (existing) {
      throw new ConflictException('Un profil technicien existe déjà pour cet utilisateur');
    }
    const technician = new this.technicianModel(dto);
    return (await technician.save()).populate('userId', '-password');
  }

  async findAll(
    department?: string,
    service?: string,
    isActive?: boolean,
  ): Promise<TechnicianDocument[]> {
    const filter: Record<string, any> = {};
    if (department) filter.technicalDepartment = new RegExp(department.trim(), 'i');
    if (service) filter.service = new RegExp(service.trim(), 'i');
    if (typeof isActive === 'boolean') filter.isActive = isActive;

    return this.technicianModel
      .find(filter)
      .populate('userId', '-password')
      .sort({ createdAt: -1 })
      .exec();
  }

  async findById(id: string): Promise<TechnicianDocument> {
    const tech = await this.technicianModel
      .findById(id)
      .populate('userId', '-password')
      .exec();
    if (!tech) {
      throw new NotFoundException(`Technicien introuvable avec l'ID : ${id}`);
    }
    return tech;
  }

  async findByUserId(userId: string): Promise<TechnicianDocument | null> {
    return this.technicianModel
      .findOne({ userId })
      .populate('userId', '-password')
      .exec();
  }

  async update(id: string, dto: UpdateTechnicianDto): Promise<TechnicianDocument> {
    const tech = await this.technicianModel
      .findByIdAndUpdate(id, dto, { new: true })
      .populate('userId', '-password')
      .exec();
    if (!tech) {
      throw new NotFoundException(`Technicien introuvable avec l'ID : ${id}`);
    }
    return tech;
  }

  async remove(id: string): Promise<{ message: string }> {
    const tech = await this.technicianModel.findByIdAndDelete(id).exec();
    if (!tech) {
      throw new NotFoundException(`Technicien introuvable avec l'ID : ${id}`);
    }
    return { message: 'Profil technicien supprimé avec succès' };
  }

  async count(): Promise<number> {
    return this.technicianModel.countDocuments({ isActive: true }).exec();
  }

  async removeByUserId(userId: string): Promise<void> {
    await this.technicianModel.deleteOne({ userId }).exec();
  }
}
