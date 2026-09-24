import { Module, forwardRef } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AiAssistantModule } from '../ai-assistant/ai-assistant.module';
import { Consultation, ConsultationSchema } from '../consultations/schemas/consultation.schema';
import { Exam, ExamSchema } from '../exams/schemas/exam.schema';
import { HospitalStay, HospitalStaySchema } from '../hospitalization/schemas/hospital-stay.schema';
import { QrCodeModule } from '../qr-code/qr-code.module';
import { User, UserSchema } from '../users/schemas/user.schema';
import { VitalSign, VitalSignSchema } from '../vital-signs/schemas/vital-sign.schema';
import { PatientsController } from './patients.controller';
import { PatientsService } from './patients.service';
import { Patient, PatientSchema } from './schemas/patient.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Patient.name, schema: PatientSchema },
      { name: User.name, schema: UserSchema },
      { name: Consultation.name, schema: ConsultationSchema },
      { name: Exam.name, schema: ExamSchema },
      { name: VitalSign.name, schema: VitalSignSchema },
      { name: HospitalStay.name, schema: HospitalStaySchema },
    ]),
    forwardRef(() => QrCodeModule),
    forwardRef(() => AiAssistantModule),
  ],
  controllers: [PatientsController],
  providers: [PatientsService],
  exports: [PatientsService, MongooseModule],
})
export class PatientsModule {}
