import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { NotificationsModule } from '../notifications/notifications.module';
import { PatientsModule } from '../patients/patients.module';
import { ClinicalEventsController } from './clinical-events.controller';
import { ClinicalEventsService } from './clinical-events.service';
import { ClinicalEvent, ClinicalEventSchema } from './schemas/clinical-event.schema';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: ClinicalEvent.name, schema: ClinicalEventSchema }]),
    NotificationsModule,
    PatientsModule,
  ],
  controllers: [ClinicalEventsController],
  providers: [ClinicalEventsService],
  exports: [ClinicalEventsService],
})
export class ClinicalEventsModule {}
