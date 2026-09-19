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
import { AlertLevel } from '../common/enums/alert-level.enum';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { AlertsService } from './alerts.service';
import { CreateAlertDto } from './dto/alert.dto';

@ApiTags('Alertes Médicales Intelligentes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('alerts')
export class AlertsController {
  constructor(private readonly alertsService: AlertsService) {}

  @Post()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({
    summary:
      'Créer une alerte médicale (Médecin, Infirmier, Sage-Femme, Administrateur)',
  })
  create(
    @Body() dto: CreateAlertDto,
    @CurrentUser('sub') userId: string,
  ) {
    return this.alertsService.create(dto, userId);
  }

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({
    summary: 'Consulter les alertes médicales avec filtrage par gravité ou statut',
  })
  @ApiQuery({ name: 'level', enum: AlertLevel, required: false })
  @ApiQuery({ name: 'isResolved', type: Boolean, required: false })
  @ApiQuery({ name: 'patientId', required: false })
  findAll(
    @CurrentUser('role') userRole: Role,
    @CurrentUser('sub') userId: string,
    @Query('level') level?: AlertLevel,
    @Query('isResolved') isResolved?: string,
    @Query('patientId') patientId?: string,
  ) {
    const resolved =
      isResolved !== undefined ? isResolved === 'true' : undefined;
    return this.alertsService.findAll({
      level,
      isResolved: resolved,
      patientId,
      role: userRole,
      userId,
    });
  }

  @Patch('resolve-all')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Marquer toutes les alertes en attente comme traitées/résolues' })
  resolveAll(
    @CurrentUser('role') userRole: Role,
    @CurrentUser('sub') userId: string,
  ) {
    return this.alertsService.resolveAll(userId, userRole);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Obtenir les détails d’une alerte' })
  findOne(@Param('id') id: string) {
    return this.alertsService.findById(id);
  }

  @Patch(':id/resolve')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE)
  @ApiOperation({ summary: 'Marquer une alerte médicale comme traitée/résolue' })
  resolve(
    @Param('id') id: string,
    @CurrentUser('sub') userId: string,
  ) {
    return this.alertsService.resolve(id, userId);
  }
}
