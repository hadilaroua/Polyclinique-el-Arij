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
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { CreateClinicServiceDto, UpdateClinicServiceDto } from './dto/clinic-service.dto';
import { ClinicServicesService } from './clinic-services.service';

@ApiTags('Services Clinique')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('services')
export class ClinicServicesController {
  constructor(private readonly clinicServicesService: ClinicServicesService) {}

  @Post()
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Créer un nouveau service clinique (Admin uniquement)' })
  create(@Body() dto: CreateClinicServiceDto) {
    return this.clinicServicesService.create(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Lister tous les services clinique' })
  @ApiQuery({ name: 'active', required: false, description: 'Filtrer uniquement les services actifs' })
  findAll(@Query('active') active?: string) {
    return this.clinicServicesService.findAll(active === 'true');
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Obtenir un service clinique par ID' })
  findOne(@Param('id') id: string) {
    return this.clinicServicesService.findById(id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Mettre à jour un service clinique (Admin uniquement)' })
  update(@Param('id') id: string, @Body() dto: UpdateClinicServiceDto) {
    return this.clinicServicesService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer un service clinique (Admin uniquement)' })
  remove(@Param('id') id: string) {
    return this.clinicServicesService.remove(id);
  }
}
