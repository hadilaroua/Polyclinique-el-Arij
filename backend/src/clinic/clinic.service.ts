import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { UpdateClinicInfoDto } from './dto/update-clinic.dto';
import { ClinicInfo, ClinicInfoDocument } from './schemas/clinic-info.schema';

@Injectable()
export class ClinicService {
  constructor(
    @InjectModel(ClinicInfo.name)
    private clinicModel: Model<ClinicInfoDocument>,
  ) {}

  async getClinicInfo(): Promise<ClinicInfoDocument> {
    let clinic = await this.clinicModel.findOne().exec();
    if (!clinic) {
      clinic = await this.clinicModel.create({
        name: 'Polyclinique Arij Djerba',
        slogan: 'Excellence médicale et assistance continue au cœur de Djerba',
        address: 'Avenue Habib Bourguiba, Midoun, Djerba 4116, Tunisie',
        phonePrimary: '+216 75 730 000',
        emergencyPhone: '+216 75 730 112',
        email: 'contact@polyclinique-arij.tn',
        website: 'https://polyclinique-arij.tn',
        openingHours: 'Service d’urgences 24h/24 et 7j/7 — Consultations 08h à 20h',
        latitude: 33.8075,
        longitude: 10.9922,
        departments: [
          {
            name: 'Cardiologie',
            description: 'Soins et consultations cardiovasculaires avancés',
            headDoctor: 'Dr. Karima Trabelsi',
          },
          {
            name: 'Pédiatrie & Néonatologie',
            description: 'Suivi et prise en charge des nouveau-nés et enfants',
            headDoctor: 'Dr. Youssef Mahfoudh',
          },
          {
            name: 'Urgences & Réanimation',
            description: 'Accueil des urgences médicales et chirurgicales 24/7',
            headDoctor: 'Dr. Sofiene Ben Amar',
          },
          {
            name: 'Radiologie & Imagerie',
            description: 'Scanner hélicoïdal, échographie Doppler, radiographie numérique',
            headDoctor: 'Dr. Monia Gharbi',
          },
        ],
        services: [
          'Urgences médico-chirurgicales 24h/24',
          'Bloc opératoire moderne',
          'Imagerie Médicale (Scanner, Échographie, Radio)',
          'Laboratoire d’analyses médicales 24/7',
          'Chirurgie ambulatoire & hospitalisation',
          'Pharmacie interne de garde',
        ],
        practicalInfo: [
          'Prise en charge conventions CNAM et assurances privées tunisiennes et internationales',
          'Ambulances médicalisées disponibles pour transferts d’urgence',
          'Parking surveillé gratuit 24/7 pour les patients et visiteurs',
          'Accès adapté aux personnes à mobilité réduite (PMR)',
        ],
      });
    }
    return clinic;
  }

  async updateClinicInfo(
    updateDto: UpdateClinicInfoDto,
  ): Promise<ClinicInfoDocument> {
    const clinic = await this.getClinicInfo();
    Object.assign(clinic, updateDto);
    return clinic.save();
  }
}
