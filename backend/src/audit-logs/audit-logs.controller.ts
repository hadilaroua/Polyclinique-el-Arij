import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuditLogsService } from './audit-logs.service';
import { CreateAuditLogDto } from './dto/audit-log.dto';

@ApiTags('Audit Logs — Traçabilité Clinique')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('audit-logs')
export class AuditLogsController {
  constructor(private readonly auditLogsService: AuditLogsService) {}

  @Post()
  @ApiOperation({ summary: 'Enregistrer une action dans le journal d\'audit' })
  async create(@Body() dto: CreateAuditLogDto) {
    return this.auditLogsService.create(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE)
  @ApiOperation({ summary: 'Récupérer le journal d\'audit complet ou filtré' })
  async findAll(
    @Query('category') category?: string,
    @Query('actorId') actorId?: string,
    @Query('patientId') patientId?: string,
    @Query('action') action?: string,
    @Query('limit') limit?: number,
  ) {
    return this.auditLogsService.findAll({
      category,
      actorId,
      patientId,
      action,
      limit: limit ? Number(limit) : 100,
    });
  }

  @Get('patient/:patientId')
  @ApiOperation({ summary: 'Historique des actes réalisés sur un patient' })
  async findByPatient(@Param('patientId') patientId: string) {
    return this.auditLogsService.findByPatient(patientId);
  }

  @Get('actor/:actorId')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Historique des actes réalisés par un soignant' })
  async findByActor(@Param('actorId') actorId: string) {
    return this.auditLogsService.findByActor(actorId);
  }
}
