import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import * as bcrypt from 'bcrypt';
import { Model, Types } from 'mongoose';
import { DoctorsService } from '../doctors/doctors.service';
import { NursesService } from '../nurses/nurses.service';
import { PatientsService } from '../patients/patients.service';
import { Role } from '../common/enums/role.enum';
import { assertMongoObjectId, isMongoObjectId } from '../common/utils/mongo-id';
import {
  CreateAuthorizedStaffDto,
  UpdateAuthorizedStaffDto,
} from './dto/authorized-staff.dto';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import {
  AuthorizedStaff,
  AuthorizedStaffDocument,
} from './schemas/authorized-staff.schema';
import { User, UserDocument } from './schemas/user.schema';

@Injectable()
export class UsersService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(AuthorizedStaff.name)
    private staffModel: Model<AuthorizedStaffDocument>,
    private readonly patientsService: PatientsService,
    private readonly doctorsService: DoctorsService,
    private readonly nursesService: NursesService,
  ) {}

  async create(createUserDto: CreateUserDto): Promise<UserDocument> {
    const existing = await this.userModel.findOne({
      email: createUserDto.email.toLowerCase().trim(),
    });

    if (existing) {
      throw new ConflictException('Cette adresse email est déjà enregistrée');
    }

    if (createUserDto.cin) {
      const existingCin = await this.userModel.findOne({
        cin: createUserDto.cin.trim(),
      });
      if (existingCin) {
        throw new ConflictException(
          'Ce numéro de pièce d’identité est déjà associé à un compte',
        );
      }
    }

    const hashedPassword = await bcrypt.hash(createUserDto.password, 10);

    const user = new this.userModel({
      ...createUserDto,
      email: createUserDto.email.toLowerCase().trim(),
      password: hashedPassword,
      cin: createUserDto.cin ? createUserDto.cin.trim() : null,
    });

    return user.save();
  }

  async findAll(role?: string): Promise<UserDocument[]> {
    const filter: Record<string, any> = {};
    if (role) {
      filter.role = role;
    }
    return this.userModel.find(filter).select('-password').exec();
  }

  async findById(id: string): Promise<UserDocument> {
    assertMongoObjectId(id, 'ID utilisateur');
    const user = await this.userModel.findById(id).select('-password').exec();
    if (!user) {
      throw new NotFoundException(`Utilisateur introuvable avec l'ID : ${id}`);
    }
    return user;
  }

  /**
   * Recherche par _id MongoDB ou par CIN (pièce d’identité).
   */
  async findByIdOrCin(identifier: string): Promise<UserDocument> {
    const key = identifier.trim();
    const user = isMongoObjectId(key)
      ? await this.userModel.findById(key).select('-password').exec()
      : await this.userModel.findOne({ cin: key }).select('-password').exec();

    if (!user) {
      throw new NotFoundException(
        `Utilisateur introuvable avec l'identifiant : ${key}`,
      );
    }
    return user;
  }

  async findDetailsByIdOrCin(identifier: string) {
    const user = await this.findByIdOrCin(identifier);
    const userId = user._id.toString();

    const [patient, doctor, nurse] = await Promise.all([
      user.role === Role.PATIENT
        ? this.patientsService.findByUserId(userId)
        : Promise.resolve(null),
      user.role === Role.DOCTOR
        ? this.doctorsService.findByUserId(userId)
        : Promise.resolve(null),
      user.role === Role.NURSE
        ? this.nursesService.findByUserId(userId)
        : Promise.resolve(null),
    ]);

    return {
      ...user.toObject(),
      id: userId,
      patient,
      doctor,
      nurse,
    };
  }

  async findByEmail(
    email: string,
    includePassword = false,
  ): Promise<UserDocument | null> {
    const query = this.userModel.findOne({ email: email.toLowerCase().trim() });
    if (includePassword) {
      query.select('+password');
    }
    return query.exec();
  }

  async findByCin(cin: string): Promise<UserDocument | null> {
    return this.userModel.findOne({ cin: cin.trim() }).exec();
  }

  async assignCinToUser(email: string, cin: string): Promise<void> {
    await this.userModel
      .findOneAndUpdate(
        { email: email.toLowerCase().trim() },
        { cin: cin.trim() },
        { new: true },
      )
      .exec();
  }

  async update(id: string, updateUserDto: UpdateUserDto): Promise<UserDocument> {
    const existing = await this.findByIdOrCin(id);
    const user = await this.userModel
      .findByIdAndUpdate(existing._id, updateUserDto, { new: true })
      .select('-password')
      .exec();

    if (!user) {
      throw new NotFoundException(`Utilisateur introuvable avec l'identifiant : ${id}`);
    }
    return user;
  }

  async updatePassword(id: string, newPasswordHash: string): Promise<void> {
    assertMongoObjectId(id, 'ID utilisateur');
    const res = await this.userModel.findByIdAndUpdate(id, {
      password: newPasswordHash,
    });
    if (!res) {
      throw new NotFoundException(`Utilisateur introuvable avec l'ID : ${id}`);
    }
  }

  async remove(id: string): Promise<{ message: string }> {
    const user = await this.findByIdOrCin(id);
    const userId = user._id.toString();

    await Promise.all([
      this.patientsService.removeByUserId(userId),
      this.doctorsService.removeByUserId(userId),
      this.nursesService.removeByUserId(userId),
    ]);

    if (user.cin) {
      await this.staffModel.deleteOne({ cin: user.cin }).exec();
    }

    await this.userModel.findByIdAndDelete(user._id).exec();
    return {
      message: `Utilisateur ${user.firstName} ${user.lastName} (CIN ${user.cin || userId}) supprimé avec succès`,
    };
  }

  async count(filter = {}): Promise<number> {
    return this.userModel.countDocuments(filter).exec();
  }

  // ==========================================
  // GESTION DU REGISTRE DU PERSONNEL AUTORISÉ
  // ==========================================

  async findAuthorizedStaffByCin(
    cin: string,
  ): Promise<AuthorizedStaffDocument | null> {
    return this.staffModel.findOne({ cin: cin.trim() }).exec();
  }

  async markStaffAsRegistered(
    cin: string,
    userId: string,
  ): Promise<AuthorizedStaffDocument | null> {
    return this.staffModel
      .findOneAndUpdate(
        { cin: cin.trim() },
        { isRegistered: true, registeredUserId: new Types.ObjectId(userId) },
        { new: true },
      )
      .exec();
  }

  async createAuthorizedStaff(
    data: Partial<AuthorizedStaff>,
  ): Promise<AuthorizedStaffDocument> {
    return this.staffModel
      .findOneAndUpdate(
        { cin: data.cin?.trim() },
        {
          $set: {
            ...data,
            cin: data.cin?.trim(),
          },
        },
        { new: true, upsert: true, runValidators: true },
      )
      .exec();
  }

  async countAuthorizedStaff(): Promise<number> {
    return this.staffModel.countDocuments().exec();
  }

  async findAllAuthorizedStaff(): Promise<AuthorizedStaffDocument[]> {
    return this.staffModel.find().sort({ createdAt: -1 }).exec();
  }

  async authorizeStaff(
    dto: CreateAuthorizedStaffDto,
  ): Promise<AuthorizedStaffDocument> {
    const cin = dto.cin.trim();
    const firstName = dto.firstName.trim();
    const lastName = dto.lastName.trim();

    if (dto.role === Role.DOCTOR && !dto.specialty?.trim()) {
      throw new ConflictException('La spécialité est obligatoire pour un médecin');
    }
    if (dto.role === Role.DOCTOR && !dto.licenseNumber?.trim()) {
      throw new ConflictException('Le numéro d’ordre médical est obligatoire pour un médecin');
    }
    if (dto.role === Role.NURSE && !dto.department?.trim()) {
      throw new ConflictException('Le service est obligatoire pour un infirmier');
    }

    const existing = await this.staffModel.findOne({ cin }).exec();
    if (existing) {
      throw new ConflictException(`Le CIN ${cin} est déjà présent dans le registre autorisé`);
    }

    return this.staffModel.create({
      cin,
      firstName,
      lastName,
      role: dto.role,
      specialty: dto.specialty?.trim() || '',
      licenseNumber: dto.licenseNumber?.trim() || '',
      department: dto.department?.trim() || '',
    });
  }

  async authorizePatient(
    cin: string,
    firstName: string,
    lastName: string,
    email: string,
  ): Promise<AuthorizedStaffDocument> {
    const cleanCin = cin.trim();
    const existing = await this.staffModel.findOne({ cin: cleanCin }).exec();
    if (existing) {
      throw new ConflictException(`Le CIN ${cleanCin} est déjà présent dans le registre autorisé`);
    }

    return this.staffModel.create({
      cin: cleanCin,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: email.toLowerCase().trim(),
      role: Role.PATIENT,
      specialty: '',
      licenseNumber: '',
      department: '',
    });
  }

  async updateAuthorizedStaff(
    cin: string,
    dto: UpdateAuthorizedStaffDto,
  ): Promise<AuthorizedStaffDocument> {
    const staff = await this.staffModel
      .findOneAndUpdate(
        { cin: cin.trim() },
        {
          ...(dto.firstName && { firstName: dto.firstName.trim() }),
          ...(dto.lastName && { lastName: dto.lastName.trim() }),
          ...(dto.specialty !== undefined && { specialty: dto.specialty.trim() }),
          ...(dto.licenseNumber !== undefined && { licenseNumber: dto.licenseNumber.trim() }),
          ...(dto.department !== undefined && { department: dto.department.trim() }),
        },
        { new: true, runValidators: true },
      )
      .exec();

    if (!staff) {
      throw new NotFoundException(`Aucune autorisation trouvée pour le CIN ${cin}`);
    }
    return staff;
  }
}
