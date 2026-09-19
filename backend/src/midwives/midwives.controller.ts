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
import { CreateMidwifeDto, UpdateMidwifeDto } from './dto/midwife.dto';
import { MidwivesService } from './midwives.service';

@ApiTags('Sages-femmes')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('midwives')
export class MidwivesController {
  constructor(private readonly midwivesService: MidwivesService) {}

  @Post()
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Créer un profil sage-femme (Admin uniquement)' })
  create(@Body() dto: CreateMidwifeDto) {
    return this.midwivesService.create(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Lister toutes les sages-femmes' })
  @ApiQuery({ name: 'service', required: false })
  @ApiQuery({ name: 'active', required: false })
  findAll(
    @Query('service') service?: string,
    @Query('active') active?: string,
  ) {
    const isActive = active === 'true' ? true : active === 'false' ? false : undefined;
    return this.midwivesService.findAll(service, isActive);
  }

  @Get('me')
  @Roles(Role.MIDWIFE)
  @ApiOperation({ summary: 'Consulter mon propre profil sage-femme' })
  findMe(@CurrentUser('sub') userId: string) {
    return this.midwivesService.findByUserId(userId);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR)
  @ApiOperation({ summary: 'Obtenir un profil sage-femme par ID' })
  findOne(@Param('id') id: string) {
    return this.midwivesService.findById(id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Mettre à jour un profil sage-femme (Admin uniquement)' })
  update(@Param('id') id: string, @Body() dto: UpdateMidwifeDto) {
    return this.midwivesService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer un profil sage-femme (Admin uniquement)' })
  remove(@Param('id') id: string) {
    return this.midwivesService.remove(id);
  }
}
