import { Controller, HttpCode, Post } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Public } from '../common/decorators/public.decorator';
import { SeedService } from './seed.service';

@ApiTags('Initialisation & Données de Démonstration')
@Controller('database')
export class DatabaseController {
  constructor(private readonly seedService: SeedService) {}

  @Public()
  @Post('seed')
  @ApiOperation({
    summary:
      'Générer ou réinitialiser les données de test (Admin, Médecins, Infirmière, Patients avec QR codes)',
  })
  @ApiResponse({
    status: 200,
    description: 'Données de démonstration insérées avec succès',
  })
  seed() {
    return this.seedService.runSeed();
  }

  @Public()
  @Post('reset-test-cins')
  @HttpCode(200)
  @ApiOperation({
    summary: '🔄 Réinitialiser les CINs de test pour Swagger',
    description:
      'Supprime les comptes créés avec les CINs de test (05050505→10101010) et remet isRegistered à false. ' +
      'Utiliser avant de retester POST /auth/register-staff dans Swagger.',
  })
  @ApiResponse({
    status: 200,
    description: 'CINs de test réinitialisés avec succès',
  })
  resetTestCins() {
    return this.seedService.resetTestCins();
  }
}
