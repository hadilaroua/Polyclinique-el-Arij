import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { CreateVitalSignDto } from './dto/vital-sign.dto';
import { VitalSignsService } from './vital-signs.service';

@ApiTags('Constantes vitales')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('vital-signs')
export class VitalSignsController {
  constructor(private readonly vitalSignsService: VitalSignsService) {}

  @Post()
  @Roles(Role.NURSE, Role.MIDWIFE, Role.DOCTOR, Role.ADMIN, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Enregistrer des constantes vitales pour un patient' })
  create(
    @Body() dto: CreateVitalSignDto,
    @CurrentUser('sub') userId: string,
  ) {
    if (!dto.recordedByUserId) {
      dto.recordedByUserId = userId;
    }
    if (!dto.recordedAt) {
      dto.recordedAt = new Date().toISOString();
    }
    return this.vitalSignsService.create(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Lister les constantes vitales avec filtre patient optionnel' })
  @ApiQuery({ name: 'patientId', required: false, description: 'ID du patient' })
  @ApiQuery({ name: 'limit', required: false, description: 'Nombre max de résultats (défaut: 50)' })
  findAll(
    @Query('patientId') patientId?: string,
    @Query('limit') limit?: string,
  ) {
    if (patientId) {
      return this.vitalSignsService.findByPatient(patientId, limit ? +limit : 50);
    }
    return this.vitalSignsService.findAll(limit ? +limit : 50);
  }

  @Get('patient/:patientId')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Historique des constantes vitales d\'un patient' })
  @ApiQuery({ name: 'limit', required: false, description: 'Nombre max de résultats (défaut: 50)' })
  findByPatient(
    @Param('patientId') patientId: string,
    @Query('limit') limit?: string,
  ) {
    return this.vitalSignsService.findByPatient(patientId, limit ? +limit : 50);
  }

  @Get('patient/:patientId/latest')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Dernière mesure de constantes vitales d\'un patient' })
  findLatest(@Param('patientId') patientId: string) {
    return this.vitalSignsService.findLatestByPatient(patientId);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Obtenir un enregistrement de constantes vitales par ID' })
  findOne(@Param('id') id: string) {
    return this.vitalSignsService.findById(id);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer un enregistrement de constantes vitales (Admin)' })
  remove(@Param('id') id: string) {
    return this.vitalSignsService.remove(id);
  }
}
