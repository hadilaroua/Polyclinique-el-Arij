import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ClinicController } from './clinic.controller';
import { ClinicService } from './clinic.service';
import { ClinicInfo, ClinicInfoSchema } from './schemas/clinic-info.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: ClinicInfo.name, schema: ClinicInfoSchema },
    ]),
  ],
  controllers: [ClinicController],
  providers: [ClinicService],
  exports: [ClinicService, MongooseModule],
})
export class ClinicModule {}
