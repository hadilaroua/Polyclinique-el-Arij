import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ConfigModule } from '@nestjs/config';

import { AiAssistantController } from './ai-assistant.controller';
import { AiAssistantService } from './ai-assistant.service';
import { AiProviderService } from './services/ai-provider.service';
import { AiContextBuilderService } from './services/ai-context-builder.service';
import { DailyBriefingService } from './services/daily-briefing.service';

import { ChatSession, ChatSessionSchema } from './schemas/chat-session.schema';
import { Patient, PatientSchema } from '../patients/schemas/patient.schema';
import { Consultation, ConsultationSchema } from '../consultations/schemas/consultation.schema';
import { Exam, ExamSchema } from '../exams/schemas/exam.schema';
import { VitalSign, VitalSignSchema } from '../vital-signs/schemas/vital-sign.schema';
import { Alert, AlertSchema } from '../alerts/schemas/alert.schema';
import { Appointment, AppointmentSchema } from '../appointments/schemas/appointment.schema';
import { HospitalStay, HospitalStaySchema } from '../hospitalization/schemas/hospital-stay.schema';
import { Doctor, DoctorSchema } from '../doctors/schemas/doctor.schema';

@Module({
  imports: [
    ConfigModule,
    MongooseModule.forFeature([
      { name: ChatSession.name, schema: ChatSessionSchema },
      { name: Patient.name, schema: PatientSchema },
      { name: Consultation.name, schema: ConsultationSchema },
      { name: Exam.name, schema: ExamSchema },
      { name: VitalSign.name, schema: VitalSignSchema },
      { name: Alert.name, schema: AlertSchema },
      { name: Appointment.name, schema: AppointmentSchema },
      { name: HospitalStay.name, schema: HospitalStaySchema },
      { name: Doctor.name, schema: DoctorSchema },
    ]),
  ],
  controllers: [AiAssistantController],
  providers: [
    AiAssistantService,
    AiProviderService,
    AiContextBuilderService,
    DailyBriefingService,
  ],
})
export class AiAssistantModule {}
