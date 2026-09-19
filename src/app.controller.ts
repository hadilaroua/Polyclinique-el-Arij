import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Public } from './common/decorators/public.decorator';
import { AppService } from './app.service';

@ApiTags('Santé & Racine')
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Public()
  @Get()
  @ApiOperation({ summary: 'Vérification de l’état du serveur (Healthcheck)' })
  @ApiResponse({ status: 200, description: 'Message de bienvenue et statut de l’API' })
  getHello(): string {
    return this.appService.getHello();
  }
}

