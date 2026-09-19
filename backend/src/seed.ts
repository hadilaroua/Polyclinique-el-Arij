import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { SeedService } from './database/seed.service';

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const seedService = app.get(SeedService);
  console.log('--- Lancement manuel du seeding MongoDB ---');
  await seedService.runSeed();
  await app.close();
  console.log('--- Seeding terminé avec succès ---');
}

bootstrap().catch((err) => {
  console.error('Erreur lors du seeding :', err);
  process.exit(1);
});
