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
import { CreateConsultationDto, UpdateConsultationDto } from './dto/consultation.dto';
import { ConsultationsService } from './consultations.service';

@ApiTags('Consultations')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('consultations')
export class ConsultationsController {
  constructor(private readonly consultationsService: ConsultationsService) {}

  @Post()
  @Roles(Role.DOCTOR, Role.ADMIN)
  @ApiOperation({ summary: 'Créer une nouvelle consultation médicale' })
  create(@Body() dto: CreateConsultationDto) {
    return this.consultationsService.create(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE)
  @ApiOperation({ summary: 'Lister les consultations avec filtres' })
  @ApiQuery({ name: 'patientId', required: false })
  @ApiQuery({ name: 'doctorId', required: false })
  findAll(
    @Query('patientId') patientId?: string,
    @Query('doctorId') doctorId?: string,
  ) {
    return this.consultationsService.findAll(patientId, doctorId);
  }

  @Get('patient/:patientId')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE)
  @ApiOperation({ summary: 'Obtenir l\'historique des consultations d\'un patient' })
  findByPatient(@Param('patientId') patientId: string) {
    return this.consultationsService.findByPatient(patientId);
  }

  @Get('doctor/:doctorId')
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Obtenir les consultations d\'un médecin' })
  @ApiQuery({ name: 'date', required: false, description: 'Filtrer par date (YYYY-MM-DD)' })
  findByDoctor(
    @Param('doctorId') doctorId: string,
    @Query('date') date?: string,
  ) {
    return this.consultationsService.findByDoctor(doctorId, date);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE)
  @ApiOperation({ summary: 'Obtenir une consultation par ID' })
  findOne(@Param('id') id: string) {
    return this.consultationsService.findById(id);
  }

  @Patch(':id')
  @Roles(Role.DOCTOR, Role.ADMIN)
  @ApiOperation({ summary: 'Mettre à jour une consultation (Médecin uniquement)' })
  update(@Param('id') id: string, @Body() dto: UpdateConsultationDto) {
    return this.consultationsService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer une consultation (Admin uniquement)' })
  remove(@Param('id') id: string) {
    return this.consultationsService.remove(id);
  }
}
