import {
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { CreateSpecialtyDto, UpdateSpecialtyDto } from './dto/specialty.dto';
import { Specialty, SpecialtyDocument, SpecialtyType } from './schemas/specialty.schema';

const INITIAL_SPECIALTIES = [
  // --- Médicales ---
  { name: 'Médecine générale', type: SpecialtyType.MEDICAL },
  { name: 'Cardiologie', type: SpecialtyType.MEDICAL },
  { name: 'Pneumologie', type: SpecialtyType.MEDICAL },
  { name: 'Pédiatrie', type: SpecialtyType.MEDICAL },
  { name: 'Gastro-entérologie', type: SpecialtyType.MEDICAL },
  { name: 'Diabétologie / Endocrinologie', type: SpecialtyType.MEDICAL },
  { name: 'Dermatologie', type: SpecialtyType.MEDICAL },
  { name: 'Neurologie', type: SpecialtyType.MEDICAL },
  { name: 'Néphrologie', type: SpecialtyType.MEDICAL },
  { name: 'Carcinologie', type: SpecialtyType.MEDICAL },
  { name: 'Médecine physique et réadaptation', type: SpecialtyType.MEDICAL },
  { name: 'Rhumatologie', type: SpecialtyType.MEDICAL },
  { name: 'Ophtalmologie', type: SpecialtyType.MEDICAL },
  { name: 'ORL', type: SpecialtyType.MEDICAL },
  // --- Chirurgicales ---
  { name: 'Chirurgie vasculaire', type: SpecialtyType.SURGICAL },
  { name: 'Chirurgie viscérale', type: SpecialtyType.SURGICAL },
  { name: 'Neurochirurgie', type: SpecialtyType.SURGICAL },
  { name: 'Chirurgie orthopédique / traumatologique', type: SpecialtyType.SURGICAL },
  { name: 'Chirurgie gynécologique', type: SpecialtyType.SURGICAL },
  { name: 'Chirurgie urologique', type: SpecialtyType.SURGICAL },
  { name: 'Chirurgie pédiatrique', type: SpecialtyType.SURGICAL },
  { name: 'Chirurgie plastique / réparatrice', type: SpecialtyType.SURGICAL },
  { name: 'Chirurgie bariatrique', type: SpecialtyType.SURGICAL },
  { name: 'Anesthésie-réanimation', type: SpecialtyType.SURGICAL },
  // --- Techniques ---
  { name: 'Radiologie / Imagerie médicale', type: SpecialtyType.TECHNICAL },
  { name: 'Scanner / TDM', type: SpecialtyType.TECHNICAL },
  { name: 'Échographie', type: SpecialtyType.TECHNICAL },
  { name: 'Biologie médicale', type: SpecialtyType.TECHNICAL },
  { name: 'Bactériologie', type: SpecialtyType.TECHNICAL },
  { name: 'Biologie de la reproduction / PMA', type: SpecialtyType.TECHNICAL },
  { name: 'Pharmacie', type: SpecialtyType.TECHNICAL },
];

@Injectable()
export class SpecialtiesService implements OnModuleInit {
  constructor(
    @InjectModel(Specialty.name) private specialtyModel: Model<SpecialtyDocument>,
  ) {}

  async onModuleInit() {
    const count = await this.specialtyModel.countDocuments();
    if (count === 0) {
      await this.specialtyModel.insertMany(INITIAL_SPECIALTIES);
    }
  }

  async create(dto: CreateSpecialtyDto): Promise<SpecialtyDocument> {
    const existing = await this.specialtyModel.findOne({
      name: new RegExp(`^${dto.name.trim()}$`, 'i'),
    });
    if (existing) {
      throw new ConflictException(`Une spécialité nommée "${dto.name}" existe déjà`);
    }
    return this.specialtyModel.create(dto);
  }

  async findAll(type?: SpecialtyType, onlyActive = false): Promise<SpecialtyDocument[]> {
    const filter: Record<string, any> = {};
    if (type) filter.type = type;
    if (onlyActive) filter.isActive = true;
    return this.specialtyModel.find(filter).sort({ type: 1, name: 1 }).exec();
  }

  async findById(id: string): Promise<SpecialtyDocument> {
    const specialty = await this.specialtyModel.findById(id).exec();
    if (!specialty) {
      throw new NotFoundException(`Spécialité introuvable avec l'ID : ${id}`);
    }
    return specialty;
  }

  async update(id: string, dto: UpdateSpecialtyDto): Promise<SpecialtyDocument> {
    const specialty = await this.specialtyModel
      .findByIdAndUpdate(id, dto, { new: true })
      .exec();
    if (!specialty) {
      throw new NotFoundException(`Spécialité introuvable avec l'ID : ${id}`);
    }
    return specialty;
  }

  async remove(id: string): Promise<{ message: string }> {
    const specialty = await this.specialtyModel.findByIdAndDelete(id).exec();
    if (!specialty) {
      throw new NotFoundException(`Spécialité introuvable avec l'ID : ${id}`);
    }
    return { message: `Spécialité "${specialty.name}" supprimée avec succès` };
  }

  async count(): Promise<number> {
    return this.specialtyModel.countDocuments({ isActive: true }).exec();
  }
}
