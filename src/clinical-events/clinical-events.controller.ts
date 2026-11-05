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
import { ClinicalEventsService } from './clinical-events.service';
import { CheckAvailabilityDto, CreateClinicalEventDto, UpdateClinicalEventDto } from './dto/clinical-event.dto';

@ApiTags('Clinical Events (Calendrier)')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('clinical-events')
export class ClinicalEventsController {
  constructor(private readonly clinicalEventsService: ClinicalEventsService) {}

  @Post('check-availability')
  @Roles(Role.DOCTOR, Role.ADMIN, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Vérifier la disponibilité d\'une salle ou d\'un bloc opératoire' })
  checkAvailability(@Body() dto: CheckAvailabilityDto) {
    return this.clinicalEventsService.checkAvailability(dto);
  }

  @Post()
  @Roles(Role.DOCTOR, Role.ADMIN)
  @ApiOperation({ summary: 'Programmer une nouvelle intervention médicale dans le calendrier' })
  create(@Body() dto: CreateClinicalEventDto) {
    return this.clinicalEventsService.create(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Lister les événements du calendrier clinique avec filtres' })
  @ApiQuery({ name: 'date', required: false, description: 'Filtrer par date (YYYY-MM-DD)' })
  @ApiQuery({ name: 'doctorId', required: false })
  @ApiQuery({ name: 'patientId', required: false })
  @ApiQuery({ name: 'roomId', required: false })
  @ApiQuery({ name: 'status', required: false })
  findAll(
    @Query('date') date?: string,
    @Query('doctorId') doctorId?: string,
    @Query('patientId') patientId?: string,
    @Query('roomId') roomId?: string,
    @Query('status') status?: string,
  ) {
    return this.clinicalEventsService.findAll(date, doctorId, patientId, roomId, status);
  }

  @Get('google-sync/status')
  @Roles(Role.DOCTOR, Role.ADMIN)
  @ApiOperation({ summary: 'Obtenir l état de la synchronisation Google Calendar' })
  getGoogleSyncStatus() {
    return this.clinicalEventsService.getGoogleSyncStatus();
  }

  @Post('google-sync/connect')
  @Roles(Role.DOCTOR, Role.ADMIN)
  @ApiOperation({ summary: 'Connecter le compte Google Calendar pour la synchronisation' })
  connectGoogleSync(@Body('email') email?: string) {
    return this.clinicalEventsService.connectGoogleSync(email);
  }

  @Post('google-sync/disconnect')
  @Roles(Role.DOCTOR, Role.ADMIN)
  @ApiOperation({ summary: 'Déconnecter Google Calendar' })
  disconnectGoogleSync() {
    return this.clinicalEventsService.disconnectGoogleSync();
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Obtenir les détails d un événement clinique par ID' })
  findOne(@Param('id') id: string) {
    return this.clinicalEventsService.findById(id);
  }

  @Patch(':id')
  @Roles(Role.DOCTOR, Role.ADMIN)
  @ApiOperation({ summary: 'Modifier une intervention programmée' })
  update(@Param('id') id: string, @Body() dto: UpdateClinicalEventDto) {
    return this.clinicalEventsService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.DOCTOR, Role.ADMIN)
  @ApiOperation({ summary: 'Annuler une intervention et libérer la salle' })
  cancel(@Param('id') id: string) {
    return this.clinicalEventsService.cancel(id);
  }
}
