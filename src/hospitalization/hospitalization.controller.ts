import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import {
  CreateBedDto,
  CreateHospitalStayDto,
  CreateRoomDto,
  DischargePatientDto,
  UpdateBedDto,
  UpdateRoomDto,
} from './dto/hospitalization.dto';
import { BedStatus } from './schemas/bed.schema';
import { StayStatus } from './schemas/hospital-stay.schema';
import { HospitalizationService } from './hospitalization.service';

@ApiTags('Hospitalisation')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('hospitalization')
export class HospitalizationController {
  constructor(private readonly hospitalizationService: HospitalizationService) {}

  // --- ROOMS ---
  @Post('rooms')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Créer une chambre (Admin uniquement)' })
  createRoom(@Body() dto: CreateRoomDto) {
    return this.hospitalizationService.createRoom(dto);
  }

  @Get('rooms')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Lister les chambres' })
  @ApiQuery({ name: 'service', required: false })
  findRooms(@Query('service') service?: string) {
    return this.hospitalizationService.findAllRooms(service);
  }

  @Get('rooms-with-beds')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Lister les chambres groupées avec leurs lits et statuts d\'occupation' })
  @ApiQuery({ name: 'service', required: false })
  findRoomsWithBeds(@Query('service') service?: string) {
    return this.hospitalizationService.findAllRoomsWithBeds(service);
  }

  @Get('rooms/:id')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Obtenir une chambre par ID' })
  findRoom(@Param('id') id: string) {
    return this.hospitalizationService.findRoomById(id);
  }

  @Patch('rooms/:id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Mettre à jour une chambre (Admin uniquement)' })
  updateRoom(@Param('id') id: string, @Body() dto: UpdateRoomDto) {
    return this.hospitalizationService.updateRoom(id, dto);
  }

  @Delete('rooms/:id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer une chambre (Admin uniquement — uniquement si aucun lit)' })
  removeRoom(@Param('id') id: string) {
    return this.hospitalizationService.removeRoom(id);
  }

  // --- BEDS ---
  @Post('beds')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Créer un lit (Admin uniquement)' })
  createBed(@Body() dto: CreateBedDto) {
    return this.hospitalizationService.createBed(dto);
  }

  @Get('beds')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Lister les lits avec filtres et informations d\'occupation' })
  @ApiQuery({ name: 'roomId', required: false })
  @ApiQuery({ name: 'status', required: false, enum: BedStatus })
  findBeds(
    @Query('roomId') roomId?: string,
    @Query('status') status?: BedStatus,
  ) {
    return this.hospitalizationService.findAllBeds(roomId, status);
  }

  @Patch('beds/:id')
  @Roles(Role.ADMIN, Role.NURSE, Role.DOCTOR, Role.MIDWIFE)
  @ApiOperation({ summary: 'Mettre à jour le statut d\'un lit' })
  updateBed(@Param('id') id: string, @Body() dto: UpdateBedDto) {
    return this.hospitalizationService.updateBed(id, dto);
  }

  @Post('beds/:id/free')
  @Roles(Role.ADMIN, Role.NURSE, Role.DOCTOR, Role.MIDWIFE)
  @ApiOperation({ summary: 'Libérer un lit et clôturer le séjour actif' })
  freeBed(@Param('id') id: string, @Body() body?: { notes?: string }) {
    return this.hospitalizationService.freeBed(id, body?.notes);
  }

  // --- HOSPITAL STAYS ---
  @Post('stays')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Admettre un patient (crée un séjour et occupe le lit automatiquement)' })
  admitPatient(@Body() dto: CreateHospitalStayDto) {
    return this.hospitalizationService.admitPatient(dto);
  }

  @Get('stays')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Lister les séjours hospitaliers' })
  @ApiQuery({ name: 'status', required: false, enum: StayStatus })
  @ApiQuery({ name: 'service', required: false })
  @ApiQuery({ name: 'patientId', required: false })
  findStays(
    @Query('status') status?: StayStatus,
    @Query('service') service?: string,
    @Query('patientId') patientId?: string,
  ) {
    return this.hospitalizationService.findAllStays(status, service, patientId);
  }

  @Get('stays/:id')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Obtenir le détail d\'un séjour' })
  findStay(@Param('id') id: string) {
    return this.hospitalizationService.findStayById(id);
  }

  @Patch('stays/:id/discharge')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Sortie du patient (libère automatiquement le lit)' })
  dischargePatient(@Param('id') id: string, @Body() dto: DischargePatientDto) {
    return this.hospitalizationService.dischargePatient(id, dto);
  }

  @Get('stats/occupancy')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Statistiques d\'occupation des lits' })
  getOccupancyStats() {
    return this.hospitalizationService.getOccupancyStats();
  }
}
