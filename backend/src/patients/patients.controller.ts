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
import {
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { CreatePatientDto } from './dto/create-patient.dto';
import { UpdatePatientDto } from './dto/update-patient.dto';
import { PatientsService } from './patients.service';

@ApiTags('Patients')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('patients')
export class PatientsController {
  constructor(private readonly patientsService: PatientsService) {}

  /**
   * Créer un nouveau patient (entité métier — Admin uniquement en V1)
   */
  @Post()
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Créer un dossier patient (Admin uniquement)' })
  create(@Body() createPatientDto: CreatePatientDto) {
    return this.patientsService.create(createPatientDto);
  }

  /**
   * Lister tous les patients avec recherche
   */
  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Lister les patients avec recherche multi-critères' })
  @ApiQuery({ name: 'search', required: false, description: 'Recherche par nom, prénom, CIN ou numéro de dossier' })
  @ApiQuery({ name: 'active', required: false, description: 'Filtrer uniquement les patients actifs (true/false)' })
  @ApiQuery({ name: 'department', required: false, description: 'Filtrer par service / département' })
  @ApiQuery({ name: 'attendingDoctorId', required: false, description: 'Filtrer par médecin traitant' })
  @ApiQuery({ name: 'assignedMidwifeId', required: false, description: 'Filtrer par sage-femme' })
  @ApiQuery({ name: 'assignedNurseId', required: false, description: 'Filtrer par infirmière' })
  findAll(
    @Query('search') search?: string,
    @Query('active') active?: string,
    @Query('department') department?: string,
    @Query('attendingDoctorId') attendingDoctorId?: string,
    @Query('assignedMidwifeId') assignedMidwifeId?: string,
    @Query('assignedNurseId') assignedNurseId?: string,
  ) {
    const onlyActive = active === 'true';
    return this.patientsService.findAll(search, onlyActive, {
      department,
      attendingDoctorId,
      assignedMidwifeId,
      assignedNurseId,
    });
  }

  /**
   * Rechercher par numéro de dossier
   */
  @Get('by-dossier/:dossierNumber')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Rechercher un patient par numéro de dossier' })
  findByDossier(@Param('dossierNumber') dossierNumber: string) {
    return this.patientsService.findByDossierNumber(dossierNumber);
  }

  /**
   * Rechercher par CIN
   */
  @Get('by-cin/:cin')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Rechercher un patient par numéro CIN' })
  findByCin(@Param('cin') cin: string) {
    return this.patientsService.findByCin(cin);
  }

  /**
   * Obtenir un patient par ID
   */
  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Obtenir le profil complet d\'un patient par ID' })
  findOne(@Param('id') id: string) {
    return this.patientsService.findById(id);
  }

  /**
   * Mettre à jour un patient
   */
  @Patch(':id')
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Mettre à jour les informations d\'un patient' })
  update(@Param('id') id: string, @Body() updatePatientDto: UpdatePatientDto) {
    return this.patientsService.update(id, updatePatientDto);
  }

  /**
   * Régénérer le QR Code
   */
  @Post(':id/regenerate-qr')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Régénérer le QR Code d\'un patient' })
  regenerateQr(@Param('id') id: string) {
    return this.patientsService.regenerateQrCode(id);
  }

  /**
   * Désactiver un patient (suppression logique)
   */
  @Patch(':id/deactivate')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Désactiver un patient (suppression logique)' })
  deactivate(@Param('id') id: string) {
    return this.patientsService.deactivate(id);
  }

  /**
   * Supprimer définitivement un patient (Admin uniquement)
   */
  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer définitivement un patient (irréversible)' })
  remove(@Param('id') id: string) {
    return this.patientsService.remove(id);
  }
}
