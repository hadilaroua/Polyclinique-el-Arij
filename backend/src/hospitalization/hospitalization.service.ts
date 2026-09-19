import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  CreateBedDto,
  CreateHospitalStayDto,
  CreateRoomDto,
  DischargePatientDto,
  UpdateBedDto,
  UpdateRoomDto,
} from './dto/hospitalization.dto';
import { Bed, BedDocument, BedStatus } from './schemas/bed.schema';
import { HospitalStay, HospitalStayDocument, StayStatus } from './schemas/hospital-stay.schema';
import { Room, RoomDocument } from './schemas/room.schema';

@Injectable()
export class HospitalizationService {
  constructor(
    @InjectModel(Room.name) private roomModel: Model<RoomDocument>,
    @InjectModel(Bed.name) private bedModel: Model<BedDocument>,
    @InjectModel(HospitalStay.name) private stayModel: Model<HospitalStayDocument>,
  ) {}

  // --- ROOMS ---
  async createRoom(dto: CreateRoomDto): Promise<RoomDocument> {
    return this.roomModel.create(dto);
  }

  async findAllRooms(service?: string): Promise<RoomDocument[]> {
    const filter: Record<string, any> = {};
    if (service) filter.service = new RegExp(service.trim(), 'i');
    return this.roomModel.find(filter).sort({ service: 1, number: 1 }).exec();
  }

  async findRoomById(id: string): Promise<RoomDocument> {
    const room = await this.roomModel.findById(id).exec();
    if (!room) throw new NotFoundException(`Chambre introuvable avec l'ID : ${id}`);
    return room;
  }

  async updateRoom(id: string, dto: UpdateRoomDto): Promise<RoomDocument> {
    const room = await this.roomModel.findByIdAndUpdate(id, dto, { new: true }).exec();
    if (!room) throw new NotFoundException(`Chambre introuvable avec l'ID : ${id}`);
    return room;
  }

  async removeRoom(id: string): Promise<{ message: string }> {
    const bedsCount = await this.bedModel.countDocuments({ roomId: id });
    if (bedsCount > 0) {
      throw new BadRequestException(`Impossible de supprimer la chambre — ${bedsCount} lit(s) associé(s)`);
    }
    const room = await this.roomModel.findByIdAndDelete(id).exec();
    if (!room) throw new NotFoundException(`Chambre introuvable avec l'ID : ${id}`);
    return { message: `Chambre ${room.number} supprimée` };
  }

  // --- BEDS ---
  async createBed(dto: CreateBedDto): Promise<BedDocument> {
    return (await this.bedModel.create(dto)).populate('roomId', 'number service floor');
  }

  async findAllBeds(roomId?: string, status?: BedStatus): Promise<BedDocument[]> {
    const filter: Record<string, any> = {};
    if (roomId) filter.roomId = roomId;
    if (status) filter.status = status;
    return this.bedModel
      .find(filter)
      .populate('roomId', 'number service floor')
      .sort({ 'roomId': 1, number: 1 })
      .exec();
  }

  async findBedById(id: string): Promise<BedDocument> {
    const bed = await this.bedModel.findById(id).populate('roomId').exec();
    if (!bed) throw new NotFoundException(`Lit introuvable avec l'ID : ${id}`);
    return bed;
  }

  async updateBed(id: string, dto: UpdateBedDto): Promise<BedDocument> {
    const bed = await this.bedModel
      .findByIdAndUpdate(id, dto, { new: true })
      .populate('roomId', 'number service')
      .exec();
    if (!bed) throw new NotFoundException(`Lit introuvable avec l'ID : ${id}`);
    return bed;
  }

  // --- HOSPITAL STAYS ---
  async admitPatient(dto: CreateHospitalStayDto): Promise<HospitalStayDocument> {
    // Vérifier que le lit est disponible
    const bed = await this.findBedById(dto.bedId);
    if (bed.status !== BedStatus.AVAILABLE) {
      throw new BadRequestException(`Le lit ${bed.number} n'est pas disponible (statut: ${bed.status})`);
    }

    // Marquer le lit comme occupé
    await this.bedModel.findByIdAndUpdate(dto.bedId, { status: BedStatus.OCCUPIED });

    // Créer le séjour
    const stay = await this.stayModel.create({
      ...dto,
      admissionDate: new Date(dto.admissionDate),
    });

    const result = await this.stayModel.findById(stay._id)
      .populate('patientId', 'firstName lastName dossierNumber cin')
      .populate({ path: 'bedId', populate: { path: 'roomId', select: 'number service floor' } })
      .exec();
    if (!result) throw new NotFoundException(`Séjour introuvable`);
    return result;
  }

  async dischargePatient(id: string, dto: DischargePatientDto): Promise<HospitalStayDocument> {
    const stay = await this.stayModel.findById(id).exec();
    if (!stay) throw new NotFoundException(`Séjour introuvable avec l'ID : ${id}`);
    if (stay.status !== StayStatus.ACTIVE) {
      throw new BadRequestException('Ce séjour est déjà terminé ou transféré');
    }

    // Libérer le lit
    await this.bedModel.findByIdAndUpdate(stay.bedId, { status: BedStatus.AVAILABLE });

    const updatedStay = await this.stayModel.findByIdAndUpdate(
      id,
      {
        status: StayStatus.DISCHARGED,
        dischargeDate: new Date(dto.dischargeDate),
        dischargeNotes: dto.dischargeNotes || '',
      },
      { new: true },
    )
      .populate('patientId', 'firstName lastName dossierNumber')
      .exec();
    if (!updatedStay) throw new NotFoundException(`Séjour introuvable avec l'ID : ${id}`);
    return updatedStay;
  }

  async findAllStays(
    status?: StayStatus,
    service?: string,
    patientId?: string,
  ): Promise<HospitalStayDocument[]> {
    const filter: Record<string, any> = {};
    if (status) filter.status = status;
    if (service) filter.service = new RegExp(service.trim(), 'i');
    if (patientId) filter.patientId = patientId;

    return this.stayModel
      .find(filter)
      .populate('patientId', 'firstName lastName dossierNumber cin')
      .populate({ path: 'bedId', populate: { path: 'roomId', select: 'number service' } })
      .sort({ admissionDate: -1 })
      .exec();
  }

  async findStayById(id: string): Promise<HospitalStayDocument> {
    const stay = await this.stayModel
      .findById(id)
      .populate('patientId', 'firstName lastName dossierNumber cin allergies bloodType')
      .populate({ path: 'bedId', populate: { path: 'roomId', select: 'number service floor' } })
      .populate({ path: 'admittedByDoctorId', populate: { path: 'userId', select: 'firstName lastName' } })
      .exec();
    if (!stay) throw new NotFoundException(`Séjour introuvable avec l'ID : ${id}`);
    return stay;
  }

  async getOccupancyStats() {
    const totalBeds = await this.bedModel.countDocuments();
    const occupiedBeds = await this.bedModel.countDocuments({ status: BedStatus.OCCUPIED });
    const availableBeds = await this.bedModel.countDocuments({ status: BedStatus.AVAILABLE });
    const maintenanceBeds = await this.bedModel.countDocuments({ status: BedStatus.MAINTENANCE });
    const activeStays = await this.stayModel.countDocuments({ status: StayStatus.ACTIVE });

    return {
      totalBeds,
      occupiedBeds,
      availableBeds,
      maintenanceBeds,
      activeStays,
      occupancyRate: totalBeds > 0 ? Math.round((occupiedBeds / totalBeds) * 100) : 0,
    };
  }
}
