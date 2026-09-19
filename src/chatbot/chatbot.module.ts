import { Module } from '@nestjs/common';
import { ClinicModule } from '../clinic/clinic.module';
import { DoctorsModule } from '../doctors/doctors.module';
import { ChatbotController } from './chatbot.controller';
import { ChatbotService } from './chatbot.service';

@Module({
  imports: [ClinicModule, DoctorsModule],
  controllers: [ChatbotController],
  providers: [ChatbotService],
  exports: [ChatbotService],
})
export class ChatbotModule {}
