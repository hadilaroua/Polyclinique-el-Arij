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
import { CreateSpecialtyDto, UpdateSpecialtyDto } from './dto/specialty.dto';
import { SpecialtyType } from './schemas/specialty.schema';
import { SpecialtiesService } from './specialties.service';

@ApiTags('Spécialités')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('specialties')
export class SpecialtiesController {
  constructor(private readonly specialtiesService: SpecialtiesService) {}

  @Post()
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Créer une nouvelle spécialité (Admin uniquement)' })
  create(@Body() dto: CreateSpecialtyDto) {
    return this.specialtiesService.create(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Lister toutes les spécialités avec filtres' })
  @ApiQuery({ name: 'type', required: false, enum: SpecialtyType, description: 'Filtrer par type (MEDICAL, SURGICAL, TECHNICAL)' })
  @ApiQuery({ name: 'active', required: false })
  findAll(
    @Query('type') type?: SpecialtyType,
    @Query('active') active?: string,
  ) {
    return this.specialtiesService.findAll(type, active === 'true');
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Obtenir une spécialité par ID' })
  findOne(@Param('id') id: string) {
    return this.specialtiesService.findById(id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Mettre à jour une spécialité (Admin uniquement)' })
  update(@Param('id') id: string, @Body() dto: UpdateSpecialtyDto) {
    return this.specialtiesService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer une spécialité (Admin uniquement)' })
  remove(@Param('id') id: string) {
    return this.specialtiesService.remove(id);
  }
}
