import {
  Body,
  Controller,
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
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AppointmentStatus } from '../common/enums/appointment-status.enum';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { AppointmentsService } from './appointments.service';
import {
  CreateAppointmentDto,
  UpdateAppointmentStatusDto,
} from './dto/appointment.dto';

@ApiTags('Rendez-vous')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('appointments')
export class AppointmentsController {
  constructor(private readonly appointmentsService: AppointmentsService) {}

  @Post()
  @Roles(Role.PATIENT, Role.ADMIN)
  @ApiOperation({
    summary:
      'Prendre un nouveau rendez-vous (Patient ou Administrateur pour un patient)',
  })
  create(
    @Body() createDto: CreateAppointmentDto,
    @CurrentUser() user: { id: string; role: Role },
  ) {
    return this.appointmentsService.create(createDto, user);
  }

  @Get()
  @ApiOperation({
    summary:
      'Consulter les rendez-vous (renvoie automatiquement la liste filtrée selon le rôle connecté)',
  })
  @ApiQuery({ name: 'status', enum: AppointmentStatus, required: false })
  @ApiQuery({ name: 'date', required: false, description: 'Format YYYY-MM-DD' })
  findMyAppointments(
    @CurrentUser() user: { id: string; role: Role },
    @Query('status') status?: AppointmentStatus,
    @Query('date') date?: string,
  ) {
    if (user.role === Role.ADMIN) {
      return this.appointmentsService.findAll({ status, date });
    }
    return this.appointmentsService.findForCurrentUser(user);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtenir les détails d’un rendez-vous' })
  findOne(@Param('id') id: string) {
    return this.appointmentsService.findById(id);
  }

  @Patch(':id/status')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.PATIENT)
  @ApiOperation({
    summary:
      'Mettre à jour le statut du rendez-vous (CONFIRMED, CANCELLED, COMPLETED)',
  })
  updateStatus(
    @Param('id') id: string,
    @Body() updateDto: UpdateAppointmentStatusDto,
    @CurrentUser() user: { id: string; role: Role },
  ) {
    return this.appointmentsService.updateStatus(id, updateDto, user);
  }

  @Post(':id/cancel')
  @ApiOperation({ summary: 'Annuler un rendez-vous' })
  cancel(
    @Param('id') id: string,
    @Body('reason') reason: string,
    @CurrentUser() user: { id: string; role: Role },
  ) {
    return this.appointmentsService.cancel(id, reason, user);
  }
}
