import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { CreateMidwifeDto, UpdateMidwifeDto } from './dto/midwife.dto';
import { Midwife, MidwifeDocument } from './schemas/midwife.schema';

@Injectable()
export class MidwivesService {
  constructor(
    @InjectModel(Midwife.name) private midwifeModel: Model<MidwifeDocument>,
  ) {}

  async create(createMidwifeDto: CreateMidwifeDto): Promise<MidwifeDocument> {
    const existing = await this.midwifeModel.findOne({
      userId: createMidwifeDto.userId,
    });
    if (existing) {
      throw new ConflictException('Un profil sage-femme existe déjà pour cet utilisateur');
    }

    const midwife = new this.midwifeModel(createMidwifeDto);
    return (await midwife.save()).populate('userId', '-password');
  }

  async findAll(service?: string, isActive?: boolean): Promise<MidwifeDocument[]> {
    const filter: Record<string, any> = {};
    if (service) filter.service = new RegExp(service.trim(), 'i');
    if (typeof isActive === 'boolean') filter.isActive = isActive;

    return this.midwifeModel
      .find(filter)
      .populate('userId', '-password')
      .sort({ createdAt: -1 })
      .exec();
  }

  async findById(id: string): Promise<MidwifeDocument> {
    const midwife = await this.midwifeModel
      .findById(id)
      .populate('userId', '-password')
      .exec();
    if (!midwife) {
      throw new NotFoundException(`Sage-femme introuvable avec l'ID : ${id}`);
    }
    return midwife;
  }

  async findByUserId(userId: string): Promise<MidwifeDocument | null> {
    return this.midwifeModel
      .findOne({ userId })
      .populate('userId', '-password')
      .exec();
  }

  async update(id: string, dto: UpdateMidwifeDto): Promise<MidwifeDocument> {
    const midwife = await this.midwifeModel
      .findByIdAndUpdate(id, dto, { new: true })
      .populate('userId', '-password')
      .exec();
    if (!midwife) {
      throw new NotFoundException(`Sage-femme introuvable avec l'ID : ${id}`);
    }
    return midwife;
  }

  async remove(id: string): Promise<{ message: string }> {
    const midwife = await this.midwifeModel.findByIdAndDelete(id).exec();
    if (!midwife) {
      throw new NotFoundException(`Sage-femme introuvable avec l'ID : ${id}`);
    }
    return { message: 'Profil sage-femme supprimé avec succès' };
  }

  async count(): Promise<number> {
    return this.midwifeModel.countDocuments({ isActive: true }).exec();
  }

  async removeByUserId(userId: string): Promise<void> {
    await this.midwifeModel.deleteOne({ userId }).exec();
  }
}
