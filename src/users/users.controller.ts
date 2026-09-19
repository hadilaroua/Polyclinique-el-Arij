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
  ApiParam,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import {
  CreateAuthorizedStaffDto,
  CreateAuthorizedPatientDto,
  UpdateAuthorizedStaffDto,
} from './dto/authorized-staff.dto';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { UsersService } from './users.service';

@ApiTags('Utilisateurs (Admin)')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Créer un utilisateur (Administrateur uniquement)' })
  create(@Body() createUserDto: CreateUserDto) {
    return this.usersService.create(createUserDto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE, Role.MIDWIFE, Role.TECHNICIAN)
  @ApiOperation({ summary: 'Lister tous les utilisateurs avec filtre par rôle' })
  @ApiQuery({ name: 'role', enum: Role, required: false })
  findAll(@Query('role') role?: Role) {
    return this.usersService.findAll(role);
  }

  @Post('authorized-staff')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Autoriser un médecin ou un infirmier avant son inscription' })
  authorizeStaff(@Body() dto: CreateAuthorizedStaffDto) {
    return this.usersService.authorizeStaff(dto);
  }

  @Get('authorized-staff')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Lister le registre du personnel autorisé' })
  findAllAuthorizedStaff() {
    return this.usersService.findAllAuthorizedStaff();
  }

  @Post('authorized-patients')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Autoriser un patient avant son inscription' })
  authorizePatient(@Body() dto: CreateAuthorizedPatientDto) {
    return this.usersService.authorizePatient(
      dto.cin,
      dto.firstName,
      dto.lastName,
      dto.email,
    );
  }

  @Patch('authorized-staff/:cin')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Modifier une autorisation du personnel' })
  updateAuthorizedStaff(
    @Param('cin') cin: string,
    @Body() dto: UpdateAuthorizedStaffDto,
  ) {
    return this.usersService.updateAuthorizedStaff(cin, dto);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.DOCTOR, Role.NURSE)
  @ApiOperation({
    summary: 'Obtenir les détails d’un utilisateur par son ID MongoDB ou son CIN',
  })
  @ApiParam({
    name: 'id',
    description:
      'Identifiant MongoDB (24 caractères hexadécimaux) ou numéro de pièce d’identité (CIN)',
    example: '13131313',
  })
  findOne(@Param('id') id: string) {
    return this.usersService.findDetailsByIdOrCin(id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Modifier un utilisateur par ID MongoDB ou CIN' })
  @ApiParam({
    name: 'id',
    description:
      'Identifiant MongoDB (24 caractères hexadécimaux) ou numéro de pièce d’identité (CIN)',
    example: '15151515',
  })
  update(@Param('id') id: string, @Body() updateUserDto: UpdateUserDto) {
    return this.usersService.update(id, updateUserDto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer un utilisateur par ID MongoDB ou CIN' })
  @ApiParam({
    name: 'id',
    description:
      'Identifiant MongoDB (24 caractères hexadécimaux) ou numéro de pièce d’identité (CIN)',
    example: '15151515',
  })
  remove(@Param('id') id: string) {
    return this.usersService.remove(id);
  }
}
