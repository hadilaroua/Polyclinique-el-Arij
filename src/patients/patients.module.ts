import { Module, forwardRef } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { QrCodeModule } from '../qr-code/qr-code.module';
import { User, UserSchema } from '../users/schemas/user.schema';
import { PatientsController } from './patients.controller';
import { PatientsService } from './patients.service';
import { Patient, PatientSchema } from './schemas/patient.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Patient.name, schema: PatientSchema },
      { name: User.name, schema: UserSchema },
    ]),
    forwardRef(() => QrCodeModule),
  ],
  controllers: [PatientsController],
  providers: [PatientsService],
  exports: [PatientsService, MongooseModule],
})
export class PatientsModule {}
