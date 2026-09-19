import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);

  // Sécurisation HTTP Helmet
  app.use(
    helmet({
      crossOriginResourcePolicy: false,
      contentSecurityPolicy: false, // Permet le rendu des assets Swagger en dev
    }),
  );

  // Activation CORS pour les applications mobiles Flutter et web
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    allowedHeaders: 'Content-Type, Accept, Authorization',
  });

  // Préfixe global des routes REST
  app.setGlobalPrefix('api');

  // Validation globale des DTOs avec conversion automatique
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // Configuration Swagger OpenAPI
  const config = new DocumentBuilder()
    .setTitle('Polyclinique Arij Djerba — API Médicale')
    .setDescription(
      'Documentation complète de l’API REST pour la gestion et l’assistance médicale de la Polyclinique Arij Djerba – Midoun. Authentification JWT, RBAC, QR Code, Rendez-vous, Dossiers médicaux, Alertes et Assistant virtuel.',
    )
    .setVersion('1.0.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        name: 'Authorization',
        description: 'Saisissez votre Token JWT généré via /api/auth/login',
        in: 'header',
      },
      'bearer',
    )
    .addTag('Authentification', 'Inscription des patients et connexion JWT')
    .addTag('Utilisateurs (Admin)', 'Gestion administrative des utilisateurs')
    .addTag('Tableau de Bord Administrateur', 'Indicateurs clés et statistiques globales')
    .addTag('Patients', 'Gestion des fiches et dossiers des patients')
    .addTag('Médecins & Horaires', 'Annuaire des spécialistes et plannings')
    .addTag('Infirmiers', 'Gestion du personnel soignant et des gardes')
    .addTag('Sages-femmes', 'Personnel soignant maternité et obstétrique')
    .addTag('Techniciens', 'Personnel technique (Laboratoire, Radiologie, Imagerie)')
    .addTag('Services Clinique', 'Configuration des départements et services par l\'Admin')
    .addTag('Spécialités Médicales', 'Catalogue des spécialités médicales, chirurgicales et techniques')
    .addTag('Consultations Médicales', 'Prise en charge, diagnostics et prescriptions')
    .addTag('Examens & Plateau Technique', 'Workflow des examens : Demande -> Réalisation -> Résultats')
    .addTag('Constantes Vitales', 'Enregistrement et suivi des paramètres vitaux')
    .addTag('Hospitalisation', 'Gestion des chambres, lits et séjours hospitaliers')
    .addTag('Rendez-vous', 'Prise et gestion du statut des rendez-vous')
    .addTag('Dossier Médical Électronique (DME)', 'Consultations, allergies et traitements')
    .addTag('Système QR Code', 'Scan et filtrage des données selon le rôle soignant')
    .addTag('Alertes Médicales Intelligentes', 'Système d’aide à la décision soignante')
    .addTag('Notifications', 'Centre de notifications in-app')
    .addTag('Assistant Intelligent / Chatbot', 'Base de connaissances clinique et réponses FAQ')
    .addTag('Informations Clinique', 'Coordonnées, services et plateau technique')
    .addTag('Initialisation & Données de Démonstration', 'Génération des données de test')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document, {
    customSiteTitle: 'Polyclinique Arij Djerba — Documentation API',
    swaggerOptions: {
      persistAuthorization: true,
    },
  });

  const port = process.env.PORT || 3000;
  await app.listen(port, '0.0.0.0');


  logger.log(`🚀 Serveur NestJS démarré avec succès sur : http://localhost:${port}/api`);
  logger.log(`📚 Documentation interactive Swagger disponible sur : http://localhost:${port}/api/docs`);
}

bootstrap();
