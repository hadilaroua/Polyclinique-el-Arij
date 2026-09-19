import { Injectable } from '@nestjs/common';
import { AppointmentsService } from '../appointments/appointments.service';
import { ConsultationsService } from '../consultations/consultations.service';
import { DoctorsService } from '../doctors/doctors.service';
import { ExamsService } from '../exams/exams.service';
import { HospitalizationService } from '../hospitalization/hospitalization.service';
import { MidwivesService } from '../midwives/midwives.service';
import { NursesService } from '../nurses/nurses.service';
import { PatientsService } from '../patients/patients.service';
import { TechniciansService } from '../technicians/technicians.service';
import { ExamStatus } from '../exams/schemas/exam.schema';
import { AppointmentStatus } from '../common/enums/appointment-status.enum';

@Injectable()
export class DashboardService {
  constructor(
    private readonly patientsService: PatientsService,
    private readonly doctorsService: DoctorsService,
    private readonly nursesService: NursesService,
    private readonly midwivesService: MidwivesService,
    private readonly techniciansService: TechniciansService,
    private readonly appointmentsService: AppointmentsService,
    private readonly consultationsService: ConsultationsService,
    private readonly examsService: ExamsService,
    private readonly hospitalizationService: HospitalizationService,
  ) {}

  /**
   * Statistiques globales pour le dashboard Admin
   */
  async getStatistics() {
    const [
      totalPatients,
      activePatients,
      totalDoctors,
      totalNurses,
      totalMidwives,
      totalTechnicians,
      totalAppointments,
      pendingAppointments,
      todayAppointments,
      totalConsultations,
      pendingExams,
      inProgressExams,
      completedExams,
      occupancyStats,
    ] = await Promise.all([
      this.patientsService.count(),
      this.patientsService.count({ isActive: true }),
      this.doctorsService.count(),
      this.nursesService.count(),
      this.midwivesService.count(),
      this.techniciansService.count(),
      this.countAppointments(),
      this.countAppointments(AppointmentStatus.PENDING),
      this.countTodayAppointments(),
      this.consultationsService.count(),
      this.examsService.count({ status: ExamStatus.PENDING }),
      this.examsService.count({ status: ExamStatus.IN_PROGRESS }),
      this.examsService.count({ status: ExamStatus.COMPLETED }),
      this.hospitalizationService.getOccupancyStats(),
    ]);

    const totalStaff = totalDoctors + totalNurses + totalMidwives + totalTechnicians;

    return {
      // Patients
      patients: {
        total: totalPatients,
        active: activePatients,
        inactive: totalPatients - activePatients,
      },
      // Personnel
      staff: {
        total: totalStaff,
        doctors: totalDoctors,
        nurses: totalNurses,
        midwives: totalMidwives,
        technicians: totalTechnicians,
      },
      // Rendez-vous
      appointments: {
        total: totalAppointments,
        pending: pendingAppointments,
        today: todayAppointments,
      },
      // Consultations
      consultations: {
        total: totalConsultations,
      },
      // Examens
      exams: {
        pending: pendingExams,
        inProgress: inProgressExams,
        completed: completedExams,
        total: pendingExams + inProgressExams + completedExams,
      },
      // Hospitalisation
      hospitalization: occupancyStats,
      // Métadonnées
      generatedAt: new Date().toISOString(),
    };
  }

  private async countAppointments(status?: AppointmentStatus): Promise<number> {
    try {
      const filter = status ? { status } : {};
      return await this.appointmentsService.count(filter);
    } catch {
      return 0;
    }
  }

  private async countTodayAppointments(): Promise<number> {
    try {
      const today = new Date().toISOString().split('T')[0];
      return await this.appointmentsService.count({ date: today });
    } catch {
      return 0;
    }
  }
}
