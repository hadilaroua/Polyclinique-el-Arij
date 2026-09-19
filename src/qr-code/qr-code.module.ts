import { Module, forwardRef } from '@nestjs/common';
import { MedicalRecordsModule } from '../medical-records/medical-records.module';
import { PatientsModule } from '../patients/patients.module';
import { QrCodeController } from './qr-code.controller';
import { QrCodeService } from './qr-code.service';

@Module({
  imports: [
    forwardRef(() => PatientsModule),
    forwardRef(() => MedicalRecordsModule),
  ],
  controllers: [QrCodeController],
  providers: [QrCodeService],
  exports: [QrCodeService],
})
export class QrCodeModule {}
