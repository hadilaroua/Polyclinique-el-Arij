import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { ClinicService } from './clinic.service';
import { UpdateClinicInfoDto } from './dto/update-clinic.dto';

@ApiTags('Informations Clinique')
@Controller('clinic')
export class ClinicController {
  constructor(private readonly clinicService: ClinicService) {}

  @Public()
  @Get('info')
  @ApiOperation({
    summary:
      'Consulter les informations publiques de la Polyclinique Arij Djerba (services, contacts, horaires, localisation)',
  })
  getInfo() {
    return this.clinicService.getClinicInfo();
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Patch('info')
  @ApiOperation({
    summary:
      'Mettre à jour les informations de la clinique (Administrateur uniquement)',
  })
  update(@Body() updateDto: UpdateClinicInfoDto) {
    return this.clinicService.updateClinicInfo(updateDto);
  }
}
