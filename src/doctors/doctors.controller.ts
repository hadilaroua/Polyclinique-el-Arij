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
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { DoctorsService } from './doctors.service';
import {
  CreateDoctorDto,
  UpdateDoctorDto,
  UpdateScheduleDto,
} from './dto/doctor.dto';

@ApiTags('Médecins & Horaires')
@Controller('doctors')
export class DoctorsController {
  constructor(private readonly doctorsService: DoctorsService) {}

  @Public()
  @Get()
  @ApiOperation({
    summary:
      'Consulter l’annuaire des médecins (public) avec filtres par spécialité/service',
  })
  @ApiQuery({ name: 'specialty', required: false })
  @ApiQuery({ name: 'service', required: false })
  @ApiQuery({ name: 'isAvailable', required: false, type: Boolean })
  findAll(
    @Query('specialty') specialty?: string,
    @Query('service') service?: string,
    @Query('isAvailable') isAvailable?: string,
  ) {
    const isAvail =
      isAvailable !== undefined ? isAvailable === 'true' : undefined;
    return this.doctorsService.findAll({ specialty, service, isAvailable: isAvail });
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Get('me')
  @Roles(Role.DOCTOR)
  @ApiOperation({ summary: 'Consulter mon profil médecin et mes horaires' })
  getMyDoctorProfile(@CurrentUser('sub') userId: string) {
    return this.doctorsService.findByUserId(userId);
  }

  @Public()
  @Get(':id')
  @ApiOperation({
    summary: 'Consulter les détails et le planning d’un médecin',
  })
  findOne(@Param('id') id: string) {
    return this.doctorsService.findById(id);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Post()
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Créer un profil médecin (Admin uniquement)' })
  create(@Body() createDoctorDto: CreateDoctorDto) {
    return this.doctorsService.create(createDoctorDto);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Patch(':id')
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Modifier les informations d’un médecin' })
  update(@Param('id') id: string, @Body() updateDoctorDto: UpdateDoctorDto) {
    return this.doctorsService.update(id, updateDoctorDto);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Patch(':id/schedules')
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({
    summary: 'Mettre à jour le planning et les horaires de consultation',
  })
  updateSchedule(
    @Param('id') id: string,
    @Body() scheduleDto: UpdateScheduleDto,
  ) {
    return this.doctorsService.updateSchedule(id, scheduleDto.schedules);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer un médecin (Admin uniquement)' })
  remove(@Param('id') id: string) {
    return this.doctorsService.remove(id);
  }
}
