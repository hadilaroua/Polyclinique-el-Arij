import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ClinicServicesController } from './clinic-services.controller';
import { ClinicServicesService } from './clinic-services.service';
import { ClinicService, ClinicServiceSchema } from './schemas/clinic-service.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: ClinicService.name, schema: ClinicServiceSchema },
    ]),
  ],
  controllers: [ClinicServicesController],
  providers: [ClinicServicesService],
  exports: [ClinicServicesService],
})
export class ClinicServicesModule {}
