import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { CreateNurseDto, UpdateNurseDto } from './dto/nurse.dto';
import { Nurse, NurseDocument } from './schemas/nurse.schema';

@Injectable()
export class NursesService {
  constructor(
    @InjectModel(Nurse.name) private nurseModel: Model<NurseDocument>,
  ) {}

  async create(createNurseDto: CreateNurseDto): Promise<NurseDocument> {
    const existing = await this.nurseModel.findOne({
      userId: createNurseDto.userId,
    });
    if (existing) {
      throw new ConflictException(
        'Un profil infirmier existe déjà pour cet utilisateur',
      );
    }
    const nurse = new this.nurseModel(createNurseDto);
    return (await nurse.save()).populate('userId', '-password');
  }

  async findAll(department?: string): Promise<NurseDocument[]> {
    const filter: Record<string, any> = {};
    if (department) {
      filter.department = new RegExp(department.trim(), 'i');
    }
    return this.nurseModel
      .find(filter)
      .populate('userId', '-password')
      .exec();
  }

  async findById(id: string): Promise<NurseDocument> {
    const nurse = await this.nurseModel
      .findById(id)
      .populate('userId', '-password')
      .exec();

    if (!nurse) {
      throw new NotFoundException(`Infirmier introuvable avec l'ID ${id}`);
    }
    return nurse;
  }

  async findByUserId(userId: string): Promise<NurseDocument | null> {
    return this.nurseModel
      .findOne({ userId })
      .populate('userId', '-password')
      .exec();
  }

  async update(
    id: string,
    updateNurseDto: UpdateNurseDto,
  ): Promise<NurseDocument> {
    const nurse = await this.nurseModel
      .findByIdAndUpdate(id, updateNurseDto, { new: true })
      .populate('userId', '-password')
      .exec();

    if (!nurse) {
      throw new NotFoundException(`Infirmier introuvable avec l'ID ${id}`);
    }
    return nurse;
  }

  async remove(id: string): Promise<{ message: string }> {
    const nurse = await this.nurseModel.findByIdAndDelete(id).exec();
    if (!nurse) {
      throw new NotFoundException(`Infirmier introuvable avec l'ID ${id}`);
    }
    return { message: 'Profil infirmier supprimé avec succès' };
  }

  async count(): Promise<number> {
    return this.nurseModel.countDocuments().exec();
  }

  async removeByUserId(userId: string): Promise<void> {
    await this.nurseModel.deleteOne({ userId }).exec();
  }
}
