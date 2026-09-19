import { Module } from '@nestjs/common';
import { AppointmentsModule } from '../appointments/appointments.module';
import { ConsultationsModule } from '../consultations/consultations.module';
import { DoctorsModule } from '../doctors/doctors.module';
import { ExamsModule } from '../exams/exams.module';
import { HospitalizationModule } from '../hospitalization/hospitalization.module';
import { MidwivesModule } from '../midwives/midwives.module';
import { NursesModule } from '../nurses/nurses.module';
import { PatientsModule } from '../patients/patients.module';
import { TechniciansModule } from '../technicians/technicians.module';
import { DashboardController } from './dashboard.controller';
import { DashboardService } from './dashboard.service';

@Module({
  imports: [
    PatientsModule,
    DoctorsModule,
    NursesModule,
    MidwivesModule,
    TechniciansModule,
    AppointmentsModule,
    ConsultationsModule,
    ExamsModule,
    HospitalizationModule,
  ],
  controllers: [DashboardController],
  providers: [DashboardService],
  exports: [DashboardService],
})
export class DashboardModule {}
