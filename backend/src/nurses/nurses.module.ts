import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { NursesController } from './nurses.controller';
import { NursesService } from './nurses.service';
import { Nurse, NurseSchema } from './schemas/nurse.schema';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: Nurse.name, schema: NurseSchema }]),
  ],
  controllers: [NursesController],
  providers: [NursesService],
  exports: [NursesService, MongooseModule],
})
export class NursesModule {}
