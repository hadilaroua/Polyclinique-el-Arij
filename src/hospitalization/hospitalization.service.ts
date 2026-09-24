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

  async findAllRoomsWithBeds(service?: string): Promise<any[]> {
    const filter: Record<string, any> = {};
    if (service) filter.service = new RegExp(service.trim(), 'i');

    const rooms = await this.roomModel
      .find(filter)
      .sort({ service: 1, number: 1 })
      .lean()
      .exec();

    const beds = await this.bedModel
      .find()
      .populate('roomId', 'number service floor')
      .lean()
      .exec();

    const activeStays = await this.stayModel
      .find({ status: StayStatus.ACTIVE })
      .populate('patientId', 'firstName lastName dossierNumber cin dateOfBirth bloodType allergies gender')
      .populate('admittedByDoctorId', 'firstName lastName')
      .lean()
      .exec();

    const stayByBedId = new Map<string, any>();
    for (const stay of activeStays) {
      if (stay.bedId) {
        stayByBedId.set(stay.bedId.toString(), stay);
      }
    }

    const bedsByRoomId = new Map<string, any[]>();
    for (const bed of beds) {
      const rid = (bed.roomId?._id || bed.roomId)?.toString();
      if (!rid) continue;
      const stay = stayByBedId.get(bed._id.toString());
      const enrichedBed = {
        ...bed,
        currentStay: stay || null,
        currentPatient: stay?.patientId || null,
        isOccupied: bed.status === BedStatus.OCCUPIED || !!stay,
      };
      if (!bedsByRoomId.has(rid)) bedsByRoomId.set(rid, []);
      bedsByRoomId.get(rid)!.push(enrichedBed);
    }

    return rooms.map(room => {
      const roomBeds = bedsByRoomId.get(room._id.toString()) || [];
      const totalBeds = roomBeds.length;
      const occupiedBeds = roomBeds.filter(b => b.isOccupied).length;
      const availableBeds = totalBeds - occupiedBeds;

      return {
        ...room,
        beds: roomBeds,
        totalBeds,
        occupiedBeds,
        availableBeds,
        isFullyOccupied: totalBeds > 0 && occupiedBeds >= totalBeds,
        isPartiallyOccupied: occupiedBeds > 0 && occupiedBeds < totalBeds,
        isEmpty: occupiedBeds === 0,
      };
    });
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

  async findAllBeds(roomId?: string, status?: BedStatus): Promise<any[]> {
    const filter: Record<string, any> = {};
    if (roomId) filter.roomId = roomId;
    if (status) filter.status = status;
    const beds = await this.bedModel
      .find(filter)
      .populate('roomId', 'number service floor roomType capacity')
      .sort({ 'roomId': 1, number: 1 })
      .lean()
      .exec();

    const activeStays = await this.stayModel
      .find({ status: StayStatus.ACTIVE })
      .populate('patientId', 'firstName lastName dossierNumber cin dateOfBirth bloodType allergies gender')
      .populate('admittedByDoctorId', 'firstName lastName')
      .lean()
      .exec();

    const stayByBedId = new Map<string, any>();
    for (const stay of activeStays) {
      if (stay.bedId) {
        stayByBedId.set(stay.bedId.toString(), stay);
      }
    }

    return beds.map(bed => {
      const stay = stayByBedId.get(bed._id.toString());
      return {
        ...bed,
        currentStay: stay || null,
        currentPatient: stay?.patientId || null,
        isOccupied: bed.status === BedStatus.OCCUPIED || !!stay,
      };
    });
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

  async freeBed(bedId: string, notes?: string): Promise<{ success: boolean; message: string }> {
    await this.bedModel.findByIdAndUpdate(bedId, { status: BedStatus.AVAILABLE });
    await this.stayModel.updateMany(
      { bedId, status: StayStatus.ACTIVE },
      {
        status: StayStatus.DISCHARGED,
        dischargeDate: new Date(),
        dischargeNotes: notes || 'Lit libéré par le personnel soignant',
      },
    );
    return { success: true, message: 'Lit libéré avec succès' };
  }

  async admitPatient(dto: CreateHospitalStayDto): Promise<HospitalStayDocument> {
    // 1. Verify the bed exists and is available
    const bed = await this.bedModel.findById(dto.bedId).exec();
    if (!bed) throw new NotFoundException(`Lit introuvable avec l'ID : ${dto.bedId}`);
    if (bed.status === BedStatus.OCCUPIED) {
      throw new BadRequestException('Ce lit est déjà occupé. Veuillez en choisir un autre.');
    }
    if (bed.status === BedStatus.MAINTENANCE) {
      throw new BadRequestException('Ce lit est en maintenance et ne peut pas être attribué.');
    }

    // 2. Create the active stay
    const stay = await this.stayModel.create({
      patientId: dto.patientId,
      bedId: dto.bedId,
      service: dto.service,
      admittedByDoctorId: dto.admittedByDoctorId,
      admissionDate: new Date(dto.admissionDate),
      admissionReason: dto.admissionReason,
      status: StayStatus.ACTIVE,
    });

    // 3. Mark the bed as occupied
    await this.bedModel.findByIdAndUpdate(dto.bedId, { status: BedStatus.OCCUPIED });

    // 4. Return the populated stay
    return this.stayModel
      .findById(stay._id)
      .populate('patientId', 'firstName lastName dossierNumber cin')
      .populate({ path: 'bedId', populate: { path: 'roomId', select: 'number service floor' } })
      .exec() as Promise<HospitalStayDocument>;
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
