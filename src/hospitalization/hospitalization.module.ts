import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { HospitalizationController } from './hospitalization.controller';
import { HospitalizationService } from './hospitalization.service';
import { Bed, BedSchema } from './schemas/bed.schema';
import { HospitalStay, HospitalStaySchema } from './schemas/hospital-stay.schema';
import { Room, RoomSchema } from './schemas/room.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Room.name, schema: RoomSchema },
      { name: Bed.name, schema: BedSchema },
      { name: HospitalStay.name, schema: HospitalStaySchema },
    ]),
  ],
  controllers: [HospitalizationController],
  providers: [HospitalizationService],
  exports: [HospitalizationService],
})
export class HospitalizationModule {}
