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
import { CreateNurseDto, UpdateNurseDto } from './dto/nurse.dto';
import { NursesService } from './nurses.service';

@ApiTags('Infirmiers')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('nurses')
export class NursesController {
  constructor(private readonly nursesService: NursesService) {}

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Lister les infirmiers avec filtre par service' })
  @ApiQuery({ name: 'department', required: false })
  findAll(@Query('department') department?: string) {
    return this.nursesService.findAll(department);
  }

  @Get('me')
  @Roles(Role.NURSE)
  @ApiOperation({ summary: 'Consulter mon profil infirmier' })
  getMyNurseProfile(@CurrentUser('sub') userId: string) {
    return this.nursesService.findByUserId(userId);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Obtenir les détails d’un infirmier par son ID' })
  findOne(@Param('id') id: string) {
    return this.nursesService.findById(id);
  }

  @Post()
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Créer un profil infirmier (Admin uniquement)' })
  create(@Body() createNurseDto: CreateNurseDto) {
    return this.nursesService.create(createNurseDto);
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.NURSE)
  @ApiOperation({ summary: 'Mettre à jour un profil infirmier' })
  update(@Param('id') id: string, @Body() updateNurseDto: UpdateNurseDto) {
    return this.nursesService.update(id, updateNurseDto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer un profil infirmier (Admin uniquement)' })
  remove(@Param('id') id: string) {
    return this.nursesService.remove(id);
  }
}
