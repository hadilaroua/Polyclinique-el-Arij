import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import * as bcrypt from 'bcrypt';
import { Model } from 'mongoose';
import { AlertsService } from '../alerts/alerts.service';
import { AppointmentsService } from '../appointments/appointments.service';
import { ClinicService } from '../clinic/clinic.service';
import { AlertLevel } from '../common/enums/alert-level.enum';
import { Role } from '../common/enums/role.enum';
import { DoctorsService } from '../doctors/doctors.service';
import { Doctor, DoctorDocument } from '../doctors/schemas/doctor.schema';
import { MedicalRecordsService } from '../medical-records/medical-records.service';
import { MidwivesService } from '../midwives/midwives.service';
import { NursesService } from '../nurses/nurses.service';
import { Nurse, NurseDocument } from '../nurses/schemas/nurse.schema';
import { PatientsService } from '../patients/patients.service';
import { TechniciansService } from '../technicians/technicians.service';
import { AuthorizedStaff, AuthorizedStaffDocument } from '../users/schemas/authorized-staff.schema';
import { User, UserDocument } from '../users/schemas/user.schema';
import { UsersService } from '../users/users.service';

@Injectable()
export class SeedService implements OnApplicationBootstrap {
  private readonly logger = new Logger(SeedService.name);

  private readonly TEST_CINS = [
    '05050505',
    '06060606',
    '07070707',
    '08080808',
    '09090909',
    '10101010',
    '12121212',
    '13131313',
  ];

  constructor(
    private readonly usersService: UsersService,
    private readonly patientsService: PatientsService,
    private readonly doctorsService: DoctorsService,
    private readonly nursesService: NursesService,
    private readonly midwivesService: MidwivesService,
    private readonly techniciansService: TechniciansService,
    private readonly medicalRecordsService: MedicalRecordsService,
    private readonly appointmentsService: AppointmentsService,
    private readonly alertsService: AlertsService,
    private readonly clinicService: ClinicService,
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    @InjectModel(Doctor.name) private readonly doctorModel: Model<DoctorDocument>,
    @InjectModel(Nurse.name) private readonly nurseModel: Model<NurseDocument>,
    @InjectModel(AuthorizedStaff.name) private readonly staffModel: Model<AuthorizedStaffDocument>,
  ) {}

  /**
   * Réinitialise les CINs de test pour permettre de retester l'inscription dans Swagger.
   * Supprime les users, doctors et nurses associés aux CINs de test et remet isRegistered à false.
   */
  async resetTestCins(): Promise<{ message: string; details: any }> {
    const testCins = this.TEST_CINS;

    // 1. Supprimer les users avec ces CINs
    const delUsers = await this.userModel.deleteMany({ cin: { $in: testCins } });

    // 2. Supprimer les doctors/nurses orphelins (dont le userId n'existe plus dans users)
    const remainingUserIds = (await this.userModel.find({}, { _id: 1 }).lean()).map(
      (u) => u._id,
    );
    const delDoctors = await this.doctorModel.deleteMany({
      userId: { $nin: remainingUserIds },
    });
    const delNurses = await this.nurseModel.deleteMany({
      userId: { $nin: remainingUserIds },
    });

    // 3. Remettre isRegistered à false dans le registre des CINs accrédités
    const resetCins = await this.staffModel.updateMany(
      { cin: { $in: testCins } },
      { $set: { isRegistered: false, userId: null } },
    );

    const details = {
      usersSupprimés: delUsers.deletedCount,
      doctorsOrphelins: delDoctors.deletedCount,
      nursesOrphelins: delNurses.deletedCount,
      cinsRéinitialisés: resetCins.modifiedCount,
      cinsDisponibles: testCins,
    };

    this.logger.log(`Reset CINs test effectué : ${JSON.stringify(details)}`);

    return {
      message: '✅ CINs de test réinitialisés — vous pouvez retester l\'inscription dans Swagger.',
      details,
    };
  }

  async onApplicationBootstrap() {
    const userCount = await this.usersService.count();
    if (userCount === 0) {
      this.logger.log(
        'Base de données vide détectée. Lancement du seeding automatique...',
      );
      await this.runSeed();
    } else {
      this.logger.log(
        `Base de données prête : ${userCount} utilisateurs trouvés.`,
      );
    }
  }

  async seedAuthorizedStaff() {
    const staffList = [
      {
        cin: '01010101',
        role: Role.ADMIN,
        firstName: 'Directeur',
        lastName: 'Arij',
        department: 'Direction Générale',
        isRegistered: true,
      },
      {
        cin: '02020202',
        role: Role.DOCTOR,
        firstName: 'Karima',
        lastName: 'Trabelsi',
        specialty: 'Cardiologie',
        licenseNumber: 'TN-MED-02020202',
        department: 'Cardiologie & Urgences Vasculaires',
        isRegistered: true,
      },
      {
        cin: '03030303',
        role: Role.DOCTOR,
        firstName: 'Youssef',
        lastName: 'Mahfoudh',
        specialty: 'Pédiatrie',
        licenseNumber: 'TN-MED-03030303',
        department: 'Pédiatrie & Néonatologie',
        isRegistered: true,
      },
      {
        cin: '04040404',
        role: Role.NURSE,
        firstName: 'Sonia',
        lastName: 'Ben Amor',
        department: 'Service Urgences & Soins Intensifs',
        isRegistered: true,
      },
      // --- Nouveaux personnels accrédités PRÊTS pour tester l'inscription ---
      {
        cin: '05050505',
        role: Role.DOCTOR,
        firstName: 'Mehdi',
        lastName: 'Ben Salem',
        specialty: 'Chirurgie Générale',
        licenseNumber: 'TN-MED-05050505',
        department: 'Service Chirurgie & Bloc',
        isRegistered: false,
      },
      {
        cin: '06060606',
        role: Role.NURSE,
        firstName: 'Amira',
        lastName: 'Jaziri',
        department: 'Soins Intensifs & Réanimation',
        isRegistered: false,
      },
      {
        cin: '07070707',
        role: Role.ADMIN,
        firstName: 'Nizar',
        lastName: 'Bousetta',
        department: 'Direction Médicale',
        isRegistered: false,
      },
      // --- Jeu de test CINs supplémentaires (batch 2) — toujours disponibles pour les tests ---
      {
        cin: '08080808',
        role: Role.DOCTOR,
        firstName: 'Rania',
        lastName: 'Chaabane',
        specialty: 'Neurologie',
        licenseNumber: 'TN-MED-08080808',
        department: 'Service Neurologie',
        isRegistered: false,
      },
      {
        cin: '09090909',
        role: Role.NURSE,
        firstName: 'Meriem',
        lastName: 'Hamdi',
        department: 'Bloc Opératoire',
        isRegistered: false,
      },
      {
        cin: '10101010',
        role: Role.ADMIN,
        firstName: 'Habib',
        lastName: 'Khalil',
        department: 'Direction Administrative',
        isRegistered: false,
      },
      // Sages-femmes
      {
        cin: '11223344',
        role: Role.MIDWIFE,
        firstName: 'Fatma',
        lastName: 'Zahra',
        department: 'Maternité & Bloc Obstétrical',
        isRegistered: false,
      },
      {
        cin: '12121212',
        role: Role.MIDWIFE,
        firstName: 'Yosra',
        lastName: 'Gharbi',
        department: 'Maternité',
        isRegistered: false,
      },
      // Techniciens
      {
        cin: '55667788',
        role: Role.TECHNICIAN,
        firstName: 'Sami',
        lastName: 'Trabelsi',
        department: 'Imagerie Médicale & Radiologie',
        isRegistered: false,
      },
      {
        cin: '13131313',
        role: Role.TECHNICIAN,
        firstName: 'Mohamed',
        lastName: 'Baccouche',
        department: 'Laboratoire d’Analyses',
        isRegistered: false,
      },
    ];

    for (const staff of staffList) {
      await this.usersService.createAuthorizedStaff(staff);
    }
    this.logger.log('Registre des pièces d’identité (CIN) de la clinique Arij initialisé.');
  }

  async runSeed(): Promise<{ message: string; summary: any }> {
    // Toujours s'assurer que le registre des CINs est inséré
    await this.seedAuthorizedStaff();

    const existingAdmin = await this.usersService.findByEmail('admin@arij.tn');
    if (existingAdmin) {
      // Toujours s'assurer que le mot de passe de l'admin est Admin123!
      await this.usersService.updatePassword(
        existingAdmin._id.toString(),
        await bcrypt.hash('Admin123!', 10),
      );
      // S'assurer que la sage-femme et le technicien de démo existent
      const existingMidwife = await this.usersService.findByEmail('fatma.sagefemme@arij.tn');
      if (!existingMidwife) {
        const midwifeUser = await this.usersService.create({
          firstName: 'Fatma',
          lastName: 'Zahra',
          email: 'fatma.sagefemme@arij.tn',
          password: 'Midwife123!',
          phone: '+216 24 567 890',
          cin: '11223344',
          role: Role.MIDWIFE,
        });
        await this.usersService.markStaffAsRegistered('11223344', midwifeUser._id.toString());
        await this.midwivesService.create({
          userId: midwifeUser._id.toString(),
          service: 'Maternité & Bloc Obstétrical',
          shift: 'Matin & Garde Obstétrique (07h-15h)',
          registryId: 'SF-ARIJ-001',
          notes: 'Sage-femme coordinatrice pôle Mère-Enfant',
        });
        this.logger.log('Sage-femme de démo ajoutée : fatma.sagefemme@arij.tn');
      }

      const existingTech = await this.usersService.findByEmail('sami.technicien@arij.tn');
      if (!existingTech) {
        const techUser = await this.usersService.create({
          firstName: 'Sami',
          lastName: 'Trabelsi',
          email: 'sami.technicien@arij.tn',
          password: 'Tech123!',
          phone: '+216 25 678 901',
          cin: '55667788',
          role: Role.TECHNICIAN,
        });
        await this.usersService.markStaffAsRegistered('55667788', techUser._id.toString());
        await this.techniciansService.create({
          userId: techUser._id.toString(),
          technicalDepartment: 'Imagerie Médicale & Radiologie',
          technicalSpecialty: 'Radiologie, Scanner & Échographie',
          service: 'Plateau Technique',
          shift: 'Matin & Permanence Scanner (07h-15h)',
          registryId: 'TECH-ARIJ-001',
        });
        this.logger.log('Technicien de démo ajouté : sami.technicien@arij.tn');
      }

      this.logger.log(
        'Les comptes de démonstration existent déjà dans la base de données.',
      );
      return {
        message: 'Les données de démonstration sont prêtes (comptes staff et médical à jour).',
        summary: {
          admin: 'admin@arij.tn / Admin123! (CIN: 01010101)',
          doctors: [
            'dr.karima@arij.tn / Doctor123! (CIN: 02020202 - Cardiologie)',
            'dr.youssef@arij.tn / Doctor123! (CIN: 03030303 - Pédiatrie)',
          ],
          nurse: 'sonia.infirmiere@arij.tn / Nurse123! (CIN: 04040404)',
          midwife: 'fatma.sagefemme@arij.tn / Midwife123! (CIN: 11223344)',
          technician: 'sami.technicien@arij.tn / Tech123! (CIN: 55667788)',
          patients: [
            'hadil.patient@arij.tn / Patient123!',
            'ahmed.patient@arij.tn / Patient123!',
          ],
          readyToRegister: [
            'Médecin test : CIN 05050505 (Dr. Mehdi Ben Salem)',
            'Infirmière test : CIN 06060606 (Amira Jaziri)',
            'Sage-femme test : CIN 12121212 (Yosra Gharbi)',
            'Technicien test : CIN 13131313 (Mohamed Baccouche)',
            'Admin test : CIN 07070707 (Nizar Bousetta)',
          ],
        },
      };
    }

    this.logger.log(
      '--- Initialisation des données pour Polyclinique Arij Djerba ---',
    );

    // 1. Initialiser les informations de la clinique
    const clinic = await this.clinicService.getClinicInfo();
    this.logger.log(`Informations clinique configurées : ${clinic.name}`);

    // 2. Création de l'Administrateur
    const adminUser = await this.usersService.create({
      firstName: 'Directeur',
      lastName: 'Arij',
      email: 'admin@arij.tn',
      password: 'Admin123!',
      phone: '+216 75 730 001',
      cin: '01010101',
      role: Role.ADMIN,
    });
    await this.usersService.markStaffAsRegistered('01010101', adminUser._id.toString());
    this.logger.log('Administrateur créé : admin@arij.tn / Admin123! (CIN: 01010101)');

    // 3. Création des Médecins
    // Médecin 1: Cardiologue
    const docUser1 = await this.usersService.create({
      firstName: 'Karima',
      lastName: 'Trabelsi',
      email: 'dr.karima@arij.tn',
      password: 'Doctor123!',
      phone: '+216 98 123 456',
      cin: '02020202',
      role: Role.DOCTOR,
    });
    await this.usersService.markStaffAsRegistered('02020202', docUser1._id.toString());

    const doctor1 = await this.doctorsService.create({
      userId: docUser1._id.toString(),
      specialty: 'Cardiologie',
      licenseNumber: 'TN-MED-4421',
      service: 'Cardiologie & Urgences Vasculaires',
      officeRoom: 'Cabinet 101 - 1er Étage',
      biography:
        'Ancienne interne des hôpitaux universitaires, spécialiste en cardiologie interventionnelle et échographie cardiaque.',
      consultationFee: 60,
      schedules: [
        {
          dayOfWeek: 'Lundi',
          startTime: '08:00',
          endTime: '14:00',
          maxPatients: 12,
          isActive: true,
        },
        {
          dayOfWeek: 'Mardi',
          startTime: '14:00',
          endTime: '18:00',
          maxPatients: 10,
          isActive: true,
        },
        {
          dayOfWeek: 'Jeudi',
          startTime: '08:00',
          endTime: '13:00',
          maxPatients: 12,
          isActive: true,
        },
      ],
    });

    // Médecin 2: Pédiatre
    const docUser2 = await this.usersService.create({
      firstName: 'Youssef',
      lastName: 'Mahfoudh',
      email: 'dr.youssef@arij.tn',
      password: 'Doctor123!',
      phone: '+216 97 654 321',
      cin: '03030303',
      role: Role.DOCTOR,
    });
    await this.usersService.markStaffAsRegistered('03030303', docUser2._id.toString());

    const doctor2 = await this.doctorsService.create({
      userId: docUser2._id.toString(),
      specialty: 'Pédiatrie',
      licenseNumber: 'TN-MED-7819',
      service: 'Pédiatrie & Néonatologie',
      officeRoom: 'Cabinet 104 - 1er Étage',
      biography:
        'Spécialiste de la santé de l’enfant, du nourrisson et de la néonatologie.',
      consultationFee: 50,
      schedules: [
        {
          dayOfWeek: 'Lundi',
          startTime: '09:00',
          endTime: '15:00',
          maxPatients: 15,
          isActive: true,
        },
        {
          dayOfWeek: 'Mercredi',
          startTime: '09:00',
          endTime: '15:00',
          maxPatients: 15,
          isActive: true,
        },
        {
          dayOfWeek: 'Vendredi',
          startTime: '08:30',
          endTime: '13:30',
          maxPatients: 12,
          isActive: true,
        },
      ],
    });
    this.logger.log('2 Médecins créés (Dr. Trabelsi & Dr. Mahfoudh)');

    // 4. Création de l'Infirmière
    const nurseUser = await this.usersService.create({
      firstName: 'Sonia',
      lastName: 'Ben Amor',
      email: 'sonia.infirmiere@arij.tn',
      password: 'Nurse123!',
      phone: '+216 22 456 789',
      cin: '04040404',
      role: Role.NURSE,
    });
    await this.usersService.markStaffAsRegistered('04040404', nurseUser._id.toString());

    await this.nursesService.create({
      userId: nurseUser._id.toString(),
      department: 'Service Urgences & Soins Intensifs',
      shift: 'Matin & Soins d’urgence (07h-15h)',
      assignedRooms: ['Chambre 101', 'Chambre 102', 'Box Urgences A'],
    });
    this.logger.log('1 Infirmière créée : sonia.infirmiere@arij.tn (CIN: 04040404)');

    // 5. Création de la Sage-Femme (Maternité)
    const midwifeUser = await this.usersService.create({
      firstName: 'Fatma',
      lastName: 'Zahra',
      email: 'fatma.sagefemme@arij.tn',
      password: 'Midwife123!',
      phone: '+216 24 567 890',
      cin: '11223344',
      role: Role.MIDWIFE,
    });
    await this.usersService.markStaffAsRegistered('11223344', midwifeUser._id.toString());
    await this.midwivesService.create({
      userId: midwifeUser._id.toString(),
      service: 'Maternité & Bloc Obstétrical',
      shift: 'Matin & Garde Obstétrique (07h-15h)',
      registryId: 'SF-ARIJ-001',
      notes: 'Sage-femme coordinatrice pôle Mère-Enfant',
    });
    this.logger.log('1 Sage-femme créée : fatma.sagefemme@arij.tn (CIN: 11223344)');

    // 6. Création du Technicien (Imagerie & Radiologie)
    const techUser = await this.usersService.create({
      firstName: 'Sami',
      lastName: 'Trabelsi',
      email: 'sami.technicien@arij.tn',
      password: 'Tech123!',
      phone: '+216 25 678 901',
      cin: '55667788',
      role: Role.TECHNICIAN,
    });
    await this.usersService.markStaffAsRegistered('55667788', techUser._id.toString());
    await this.techniciansService.create({
      userId: techUser._id.toString(),
      technicalDepartment: 'Imagerie Médicale & Radiologie',
      technicalSpecialty: 'Radiologie, Scanner & Échographie',
      service: 'Plateau Technique',
      shift: 'Matin & Permanence Scanner (07h-15h)',
      registryId: 'TECH-ARIJ-001',
    });
    this.logger.log('1 Technicien créé : sami.technicien@arij.tn (CIN: 55667788)');

    // 7. Création des Patients avec QR Codes et Dossiers Médicaux
    // Patient 1: Hadil Guermazi
    const patientUser1 = await this.usersService.create({
      firstName: 'Hadil',
      lastName: 'Guermazi',
      email: 'hadil.patient@arij.tn',
      password: 'Patient123!',
      phone: '+216 20 789 123',
      cin: '11111111',
      role: Role.PATIENT,
    });
    const patient1 = await this.patientsService.create({
      userId: patientUser1._id.toString(),
      firstName: patientUser1.firstName,
      lastName: patientUser1.lastName,
      cin: patientUser1.cin || '11111111',
      phone: patientUser1.phone,
      dateOfBirth: '2001-04-12',
      gender: 'Femme',
      bloodType: 'A+',
      emergencyContact: {
        name: 'Mohamed Guermazi',
        phone: '+216 98 111 222',
        relation: 'Père',
      },
      allergies: ['Pénicilline', 'Arachides'],
      chronicDiseases: ['Asthme'],
      address: 'Zone Midoun, Djerba',
    });

    await this.medicalRecordsService.create({
      patientId: patient1._id.toString(),
      allergies: ['Pénicilline', 'Arachides'],
      antecedents: {
        personal: ['Asthme d’effort diagnostiqué en 2018'],
        family: ['Hypertension artérielle (côté maternel)'],
        surgical: [],
      },
      treatments: [
        {
          medication: 'Ventoline 100 µg',
          dosage: '1 à 2 bouffées',
          frequency: 'En cas de crise ou d’effort',
          startDate: '2026-01-10',
          prescribingDoctor: 'Dr. Karima Trabelsi',
        },
      ],
      generalNotes:
        'Patiente coopérative, protocole de surveillance asthme stable.',
    });

    await this.medicalRecordsService.addConsultation(patient1._id.toString(), {
      date: '2026-08-15T09:30:00.000Z',
      doctorName: 'Dr. Karima Trabelsi',
      doctorSpecialty: 'Cardiologie',
      motive: 'Bilan cardiaque préventif',
      diagnostic:
        'Rythme sinusal normal, tension artérielle 12/7 cmHg, pas d’anomalie',
      prescription:
        'Règles hygiéno-diététiques et poursuite activité physique modérée',
      observations: 'Prochain contrôle dans 1 an.',
    });

    // Patient 2: Ahmed Ben Salah
    const patientUser2 = await this.usersService.create({
      firstName: 'Ahmed',
      lastName: 'Ben Salah',
      email: 'ahmed.patient@arij.tn',
      password: 'Patient123!',
      phone: '+216 23 456 789',
      cin: '22222222',
      role: Role.PATIENT,
    });
    const patient2 = await this.patientsService.create({
      userId: patientUser2._id.toString(),
      firstName: patientUser2.firstName,
      lastName: patientUser2.lastName,
      cin: patientUser2.cin || '22222222',
      phone: patientUser2.phone,
      dateOfBirth: '1988-11-23',
      gender: 'Homme',
      bloodType: 'O+',
      emergencyContact: {
        name: 'Leila Ben Salah',
        phone: '+216 22 333 444',
        relation: 'Épouse',
      },
      allergies: ['Sulfamides'],
      chronicDiseases: ['Hypertension'],
      address: 'Houmt Souk, Djerba',
    });

    await this.medicalRecordsService.create({
      patientId: patient2._id.toString(),
      allergies: ['Sulfamides'],
      antecedents: {
        personal: ['HTA traitée'],
        family: ['Diabète Type 2'],
        surgical: ['Appendicectomie en 2012'],
      },
      treatments: [
        {
          medication: 'Amlodipine 5mg',
          dosage: '1 comprimé',
          frequency: 'Chaque matin',
          startDate: '2026-02-01',
          prescribingDoctor: 'Dr. Karima Trabelsi',
        },
      ],
      generalNotes: 'Suivi régulier tensionnel.',
    });

    this.logger.log('2 Patients créés avec QR codes et dossiers médicaux complets');

    // 6. Rendez-vous de démonstration
    await this.appointmentsService.create(
      {
        patientId: patient1._id.toString(),
        doctorId: doctor1._id.toString(),
        date: '2026-09-10',
        timeSlot: '09:00',
        reason: 'Consultation de suivi cardiologique annuel',
      },
      { id: adminUser._id.toString(), role: Role.ADMIN },
    );

    await this.appointmentsService.create(
      {
        patientId: patient2._id.toString(),
        doctorId: doctor2._id.toString(),
        date: '2026-09-12',
        timeSlot: '10:00',
        reason: 'Consultation pédiatrique pour son fils',
      },
      { id: adminUser._id.toString(), role: Role.ADMIN },
    );
    this.logger.log('2 Rendez-vous de démonstration créés');

    // 7. Alerte médicale d'aide à la décision
    await this.alertsService.create(
      {
        patientId: patient1._id.toString(),
        level: AlertLevel.WARNING,
        title: 'Allergie sévère à la pénicilline signalée',
        description:
          'La patiente Hadil Guermazi présente une allergie avérée à la pénicilline. Éviter toute prescription de bêta-lactamines.',
        category: 'Allergie',
        targetRoles: [Role.DOCTOR, Role.NURSE],
      },
      adminUser._id.toString(),
    );
    this.logger.log('1 Alerte clinique créée');

    this.logger.log(
      '--- Données initialisées avec succès pour la Polyclinique Arij ---',
    );

    return {
      message: 'Base de données initialisée avec succès !',
      summary: {
        admin: 'admin@arij.tn / Admin123! (CIN: 01010101)',
        doctors: [
          'dr.karima@arij.tn / Doctor123! (CIN: 02020202 - Cardiologie)',
          'dr.youssef@arij.tn / Doctor123! (CIN: 03030303 - Pédiatrie)',
        ],
        nurse: 'sonia.infirmiere@arij.tn / Nurse123! (CIN: 04040404)',
        patients: [
          'hadil.patient@arij.tn / Patient123!',
          'ahmed.patient@arij.tn / Patient123!',
        ],
        readyToRegister: [
          'Médecin test : CIN 05050505 (Dr. Mehdi Ben Salem - Chirurgie)',
          'Infirmière test : CIN 06060606 (Amira Jaziri - Soins Intensifs)',
          'Admin test : CIN 07070707 (Nizar Bousetta - Direction Médicale)',
        ],
      },
    };
  }
}
