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
import { ApiBearerAuth, ApiBody, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import {
  AssignExamDto,
  CompleteExamDto,
  CreateExamDto,
  UpdateExamDto,
} from './dto/exam.dto';
import { ExamStatus } from './schemas/exam.schema';
import { ExamsService } from './exams.service';

@ApiTags('Examens')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('exams')
export class ExamsController {
  constructor(private readonly examsService: ExamsService) {}

  @Post()
  @Roles(Role.DOCTOR, Role.ADMIN, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Créer une demande ou saisie d\'examen (Médecin / Technicien)' })
  create(@Body() dto: CreateExamDto) {
    return this.examsService.create(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE)
  @ApiOperation({ summary: 'Lister les examens avec filtres' })
  @ApiQuery({ name: 'patientId', required: false })
  @ApiQuery({ name: 'doctorId', required: false })
  @ApiQuery({ name: 'technicianId', required: false })
  @ApiQuery({ name: 'service', required: false })
  @ApiQuery({ name: 'status', required: false, enum: ExamStatus })
  @ApiQuery({ name: 'priority', required: false })
  findAll(
    @Query('patientId') patientId?: string,
    @Query('doctorId') doctorId?: string,
    @Query('technicianId') technicianId?: string,
    @Query('service') service?: string,
    @Query('status') status?: ExamStatus,
    @Query('priority') priority?: string,
  ) {
    return this.examsService.findAll({ patientId, doctorId, technicianId, service, status, priority });
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.TECHNICIAN, Role.MIDWIFE)
  @ApiOperation({ summary: 'Obtenir un examen par ID' })
  findOne(@Param('id') id: string) {
    return this.examsService.findById(id);
  }

  @Patch(':id/assign')
  @Roles(Role.ADMIN, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Assigner un technicien → passe en IN_PROGRESS' })
  assign(@Param('id') id: string, @Body() dto: AssignExamDto) {
    return this.examsService.assign(id, dto);
  }

  @Patch(':id/complete')
  @Roles(Role.TECHNICIAN, Role.ADMIN)
  @ApiOperation({ summary: 'Compléter l\'examen avec le résultat → passe en COMPLETED' })
  complete(@Param('id') id: string, @Body() dto: CompleteExamDto) {
    return this.examsService.complete(id, dto);
  }

  @Patch(':id/cancel')
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Annuler une demande d\'examen' })
  @ApiBody({ schema: { example: { reason: 'Patient transféré' } } })
  cancel(@Param('id') id: string, @Body('reason') reason: string) {
    return this.examsService.cancel(id, reason);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Mettre à jour un examen (Admin uniquement)' })
  update(@Param('id') id: string, @Body() dto: UpdateExamDto) {
    return this.examsService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer un examen (Admin uniquement)' })
  remove(@Param('id') id: string) {
    return this.examsService.remove(id);
  }
}
