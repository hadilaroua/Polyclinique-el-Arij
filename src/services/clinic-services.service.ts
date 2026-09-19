import {
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { CreateClinicServiceDto, UpdateClinicServiceDto } from './dto/clinic-service.dto';
import { ClinicService, ClinicServiceDocument } from './schemas/clinic-service.schema';

/** Services initiaux de la clinique Arij Djerba — Configurables par l'Admin */
const INITIAL_SERVICES = [
  { name: 'Urgences', description: 'Service d\'urgences 24h/24 et 7j/7', icon: 'emergency', color: '#E53E3E', displayOrder: 1 },
  { name: 'Réanimation / Soins intensifs', description: 'Unité de réanimation et soins intensifs', icon: 'monitor_heart', color: '#9B2C2C', displayOrder: 2 },
  { name: 'Maternité', description: 'Service de maternité et obstétrique', icon: 'child_care', color: '#D53F8C', displayOrder: 3 },
  { name: 'Bloc opératoire', description: 'Chirurgie et interventions programmées', icon: 'surgical', color: '#2B6CB0', displayOrder: 4 },
  { name: 'Radiologie / Scanner', description: 'Imagerie médicale, radiologie et scanner', icon: 'radiology', color: '#2D3748', displayOrder: 5 },
  { name: 'Laboratoire', description: 'Analyses biologiques et bactériologie', icon: 'biotech', color: '#276749', displayOrder: 6 },
  { name: 'PMA', description: 'Procréation médicalement assistée', icon: 'favorite', color: '#B7791F', displayOrder: 7 },
  { name: 'MPR', description: 'Médecine physique et réadaptation', icon: 'accessibility_new', color: '#2C7A7B', displayOrder: 8 },
  { name: 'Hospitalisation', description: 'Séjours hospitaliers et soins continus', icon: 'hotel', color: '#2B6CB0', displayOrder: 9 },
  { name: 'Consultations externes', description: 'Consultations ambulatoires et spécialisées', icon: 'medical_services', color: '#2DB9BB', displayOrder: 10 },
];

@Injectable()
export class ClinicServicesService implements OnModuleInit {
  constructor(
    @InjectModel(ClinicService.name) private serviceModel: Model<ClinicServiceDocument>,
  ) {}

  /**
   * Initialise les services de base si la base de données est vide
   */
  async onModuleInit() {
    const count = await this.serviceModel.countDocuments();
    if (count === 0) {
      await this.serviceModel.insertMany(INITIAL_SERVICES);
    }
  }

  async create(dto: CreateClinicServiceDto): Promise<ClinicServiceDocument> {
    const existing = await this.serviceModel.findOne({ name: new RegExp(`^${dto.name.trim()}$`, 'i') });
    if (existing) {
      throw new ConflictException(`Un service nommé "${dto.name}" existe déjà`);
    }
    return this.serviceModel.create(dto);
  }

  async findAll(onlyActive = false): Promise<ClinicServiceDocument[]> {
    const filter: Record<string, any> = {};
    if (onlyActive) filter.isActive = true;
    return this.serviceModel.find(filter).sort({ displayOrder: 1, name: 1 }).exec();
  }

  async findById(id: string): Promise<ClinicServiceDocument> {
    const service = await this.serviceModel.findById(id).exec();
    if (!service) {
      throw new NotFoundException(`Service introuvable avec l'ID : ${id}`);
    }
    return service;
  }

  async findByName(name: string): Promise<ClinicServiceDocument | null> {
    return this.serviceModel.findOne({ name: new RegExp(`^${name.trim()}$`, 'i') }).exec();
  }

  async update(id: string, dto: UpdateClinicServiceDto): Promise<ClinicServiceDocument> {
    const service = await this.serviceModel
      .findByIdAndUpdate(id, dto, { new: true })
      .exec();
    if (!service) {
      throw new NotFoundException(`Service introuvable avec l'ID : ${id}`);
    }
    return service;
  }

  async remove(id: string): Promise<{ message: string }> {
    const service = await this.serviceModel.findByIdAndDelete(id).exec();
    if (!service) {
      throw new NotFoundException(`Service introuvable avec l'ID : ${id}`);
    }
    return { message: `Service "${service.name}" supprimé avec succès` };
  }

  async count(): Promise<number> {
    return this.serviceModel.countDocuments({ isActive: true }).exec();
  }
}
