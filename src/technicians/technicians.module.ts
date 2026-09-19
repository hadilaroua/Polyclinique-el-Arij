import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { TechniciansController } from './technicians.controller';
import { TechniciansService } from './technicians.service';
import { Technician, TechnicianSchema } from './schemas/technician.schema';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: Technician.name, schema: TechnicianSchema }]),
  ],
  controllers: [TechniciansController],
  providers: [TechniciansService],
  exports: [TechniciansService],
})
export class TechniciansModule {}
