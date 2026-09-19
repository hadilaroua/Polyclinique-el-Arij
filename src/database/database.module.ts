import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AlertsModule } from '../alerts/alerts.module';
import { AppointmentsModule } from '../appointments/appointments.module';
import { ClinicModule } from '../clinic/clinic.module';
import { DoctorsModule } from '../doctors/doctors.module';
import { Doctor, DoctorSchema } from '../doctors/schemas/doctor.schema';
import { MedicalRecordsModule } from '../medical-records/medical-records.module';
import { MidwivesModule } from '../midwives/midwives.module';
import { NursesModule } from '../nurses/nurses.module';
import { Nurse, NurseSchema } from '../nurses/schemas/nurse.schema';
import { PatientsModule } from '../patients/patients.module';
import { TechniciansModule } from '../technicians/technicians.module';
import { AuthorizedStaff, AuthorizedStaffSchema } from '../users/schemas/authorized-staff.schema';
import { User, UserSchema } from '../users/schemas/user.schema';
import { UsersModule } from '../users/users.module';
import { DatabaseController } from './database.controller';
import { SeedService } from './seed.service';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },
      { name: Doctor.name, schema: DoctorSchema },
      { name: Nurse.name, schema: NurseSchema },
      { name: AuthorizedStaff.name, schema: AuthorizedStaffSchema },
    ]),
    UsersModule,
    PatientsModule,
    DoctorsModule,
    NursesModule,
    MidwivesModule,
    TechniciansModule,
    MedicalRecordsModule,
    AppointmentsModule,
    AlertsModule,
    ClinicModule,
  ],
  controllers: [DatabaseController],
  providers: [SeedService],
  exports: [SeedService],
})
export class DatabaseModule {}

