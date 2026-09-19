import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { MidwivesController } from './midwives.controller';
import { MidwivesService } from './midwives.service';
import { Midwife, MidwifeSchema } from './schemas/midwife.schema';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: Midwife.name, schema: MidwifeSchema }]),
  ],
  controllers: [MidwivesController],
  providers: [MidwivesService],
  exports: [MidwivesService],
})
export class MidwivesModule {}
