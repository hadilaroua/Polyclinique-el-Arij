import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { VitalSignsController } from './vital-signs.controller';
import { VitalSignsService } from './vital-signs.service';
import { VitalSign, VitalSignSchema } from './schemas/vital-sign.schema';

@Module({
  imports: [MongooseModule.forFeature([{ name: VitalSign.name, schema: VitalSignSchema }])],
  controllers: [VitalSignsController],
  providers: [VitalSignsService],
  exports: [VitalSignsService],
})
export class VitalSignsModule {}
