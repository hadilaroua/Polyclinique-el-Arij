import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { MongooseModule } from '@nestjs/mongoose';
import { AlertsModule } from './alerts/alerts.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AppointmentsModule } from './appointments/appointments.module';
import { AuditLogsModule } from './audit-logs/audit-logs.module';
import { AuthModule } from './auth/auth.module';
import { ChatbotModule } from './chatbot/chatbot.module';
import { ClinicModule } from './clinic/clinic.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { ConsultationsModule } from './consultations/consultations.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { DatabaseModule } from './database/database.module';
import { DoctorsModule } from './doctors/doctors.module';
import { ExamsModule } from './exams/exams.module';
import { HospitalizationModule } from './hospitalization/hospitalization.module';
import { MedicalRecordsModule } from './medical-records/medical-records.module';
import { MidwivesModule } from './midwives/midwives.module';
import { NotificationsModule } from './notifications/notifications.module';
import { NursesModule } from './nurses/nurses.module';
import { PatientsModule } from './patients/patients.module';
import { QrCodeModule } from './qr-code/qr-code.module';
import { ClinicServicesModule } from './services/clinic-services.module';
import { SpecialtiesModule } from './specialties/specialties.module';
import { TechniciansModule } from './technicians/technicians.module';
import { UsersModule } from './users/users.module';
import { VitalSignsModule } from './vital-signs/vital-signs.module';
import { AiAssistantModule } from './ai-assistant/ai-assistant.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    MongooseModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        uri:
          configService.get<string>('MONGODB_URI') ||
          'mongodb://127.0.0.1:27017/polyclinique_arij',
      }),
    }),
    UsersModule,
    AuthModule,
    PatientsModule,
    DoctorsModule,
    NursesModule,
    MidwivesModule,
    TechniciansModule,
    ClinicServicesModule,
    SpecialtiesModule,
    AppointmentsModule,
    ConsultationsModule,
    ExamsModule,
    VitalSignsModule,
    HospitalizationModule,
    MedicalRecordsModule,
    DashboardModule,
    QrCodeModule,
    ClinicModule,
    AlertsModule,
    AuditLogsModule,
    NotificationsModule,
    ChatbotModule,
    DatabaseModule,
    AiAssistantModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    {
      provide: APP_GUARD,
      useClass: RolesGuard,
    },
    {
      provide: APP_FILTER,
      useClass: AllExceptionsFilter,
    },
  ],
})
export class AppModule {}
