import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { DoctorsModule } from '../doctors/doctors.module';
import { NursesModule } from '../nurses/nurses.module';
import { PatientsModule } from '../patients/patients.module';
import {
  AuthorizedStaff,
  AuthorizedStaffSchema,
} from './schemas/authorized-staff.schema';
import { User, UserSchema } from './schemas/user.schema';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },
      { name: AuthorizedStaff.name, schema: AuthorizedStaffSchema },
    ]),
    PatientsModule,
    DoctorsModule,
    NursesModule,
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService, MongooseModule],
})
export class UsersModule {}
