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
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { CreateTechnicianDto, UpdateTechnicianDto } from './dto/technician.dto';
import { TechniciansService } from './technicians.service';

@ApiTags('Techniciens')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('technicians')
export class TechniciansController {
  constructor(private readonly techniciansService: TechniciansService) {}

  @Post()
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Créer un profil technicien (Admin uniquement)' })
  create(@Body() dto: CreateTechnicianDto) {
    return this.techniciansService.create(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Lister tous les techniciens avec filtres' })
  @ApiQuery({ name: 'department', required: false, description: 'Filtrer par département technique' })
  @ApiQuery({ name: 'service', required: false })
  @ApiQuery({ name: 'active', required: false })
  findAll(
    @Query('department') department?: string,
    @Query('service') service?: string,
    @Query('active') active?: string,
  ) {
    const isActive = active === 'true' ? true : active === 'false' ? false : undefined;
    return this.techniciansService.findAll(department, service, isActive);
  }

  @Get('me')
  @Roles(Role.TECHNICIAN)
  @ApiOperation({ summary: 'Consulter mon propre profil technicien' })
  findMe(@CurrentUser('sub') userId: string) {
    return this.techniciansService.findByUserId(userId);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Obtenir un profil technicien par ID' })
  findOne(@Param('id') id: string) {
    return this.techniciansService.findById(id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Mettre à jour un profil technicien (Admin uniquement)' })
  update(@Param('id') id: string, @Body() dto: UpdateTechnicianDto) {
    return this.techniciansService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer un profil technicien (Admin uniquement)' })
  remove(@Param('id') id: string) {
    return this.techniciansService.remove(id);
  }
}
