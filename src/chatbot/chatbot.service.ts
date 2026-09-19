import { Injectable } from '@nestjs/common';
import { ClinicService } from '../clinic/clinic.service';
import { DoctorsService } from '../doctors/doctors.service';

export interface ChatResponse {
  answer: string;
  disclaimer?: string;
  category: string;
  suggestedQuestions?: string[];
}

@Injectable()
export class ChatbotService {
  private readonly medicalDisclaimer =
    '⚠️ Note importante : Je suis un assistant virtuel d’information pour la Polyclinique Arij Djerba. Je ne peux en aucun cas poser de diagnostic médical ni prescrire de traitement. En cas d’urgence, contactez immédiatement notre service d’urgence au +216 75 730 112 ou le 198.';

  constructor(
    private readonly clinicService: ClinicService,
    private readonly doctorsService: DoctorsService,
  ) {}

  async processQuestion(userQuestion: string): Promise<ChatResponse> {
    const q = userQuestion.toLowerCase().trim();
    const clinic = await this.clinicService.getClinicInfo();

    // 1. Diagnostic ou conseils médicaux directs (Symptômes, Douleurs)
    if (
      q.includes('mal') ||
      q.includes('douleur') ||
      q.includes('symptom') ||
      q.includes('fievre') ||
      q.includes('fièvre') ||
      q.includes('diagnostic') ||
      q.includes('medicament') ||
      q.includes('ordonnance') ||
      q.includes('traitement')
    ) {
      return {
        answer:
          'Pour toute douleur, symptôme ou question médicale, nous vous recommandons vivement de consulter l’un de nos médecins spécialistes ou de vous présenter aux urgences de la Polyclinique Arij (ouvertes 24h/24).',
        disclaimer: this.medicalDisclaimer,
        category: 'MEDICAL_ADVICE_DISCLAIMER',
        suggestedQuestions: [
          'Quels médecins travaillent en cardiologie ?',
          'Comment prendre un rendez-vous ?',
          'Quels sont les horaires des urgences ?',
        ],
      };
    }

    // 2. Horaires et urgences
    if (
      q.includes('heure') ||
      q.includes('horaire') ||
      q.includes('ouvert') ||
      q.includes('fermeture') ||
      q.includes('urgence')
    ) {
      return {
        answer: `La ${clinic.name} assure un service d'urgences 24h/24 et 7j/7 avec permanence médicale et bloc opératoire. Les consultations externes en cabinet médical sont assurées du lundi au samedi de 08h00 à 20h00.`,
        category: 'HOURS_AND_EMERGENCY',
        suggestedQuestions: [
          'Où se trouve la clinique ?',
          'Comment contacter la clinique ?',
          'Comment prendre rendez-vous ?',
        ],
      };
    }

    // 3. Localisation / Adresse / Comment venir
    if (
      q.includes('adresse') ||
      q.includes('lieu') ||
      q.includes('ou se trouve') ||
      q.includes('où se trouve') ||
      q.includes('localisation') ||
      q.includes('venir') ||
      q.includes('position') ||
      q.includes('parking')
    ) {
      return {
        answer: `La ${clinic.name} est située à : ${clinic.address}. Nous disposons d'un parking gratuit et surveillé pour les patients et leurs visiteurs, ainsi que d'accès adaptés aux personnes à mobilité réduite (PMR).`,
        category: 'LOCATION',
        suggestedQuestions: [
          'Comment contacter la clinique ?',
          'Quels sont les horaires ?',
          'Quels services sont disponibles ?',
        ],
      };
    }

    // 4. Contact / Téléphone / Email
    if (
      q.includes('contact') ||
      q.includes('telephone') ||
      q.includes('téléphone') ||
      q.includes('numéro') ||
      q.includes('numero') ||
      q.includes('appeler') ||
      q.includes('email')
    ) {
      return {
        answer: `Vous pouvez contacter la clinique aux coordonnées suivantes :\n- Standard & Rendez-vous : ${clinic.phonePrimary}\n- Urgences 24/7 : ${clinic.emergencyPhone}\n- Email : ${clinic.email}\n- Site web : ${clinic.website}`,
        category: 'CONTACT',
        suggestedQuestions: [
          'Comment prendre rendez-vous ?',
          'Où se trouve la clinique ?',
        ],
      };
    }

    // 5. Recherche de médecins par spécialité (Cardiologie, Pédiatrie, etc.)
    if (
      q.includes('medecin') ||
      q.includes('médecin') ||
      q.includes('docteur') ||
      q.includes('specialite') ||
      q.includes('spécialité') ||
      q.includes('cardiolog') ||
      q.includes('pediatr') ||
      q.includes('pédiatr') ||
      q.includes('chirurg')
    ) {
      const doctors = await this.doctorsService.findAll();
      if (doctors.length > 0) {
        const docList = doctors
          .map((d) => {
            const user: any = d.userId;
            const name = user ? `Dr. ${user.firstName} ${user.lastName}` : 'Médecin';
            const sched = d.schedules
              .map((s) => `${s.dayOfWeek}: ${s.startTime}-${s.endTime}`)
              .join(' | ');
            return `• ${name} (${d.specialty}) — ${sched || 'Sur rendez-vous'}`;
          })
          .join('\n');

        return {
          answer: `Voici la liste des médecins exerçant actuellement à la clinique Arij :\n${docList}\n\nVous pouvez réserver une consultation directement depuis l'onglet "Mes rendez-vous" de l'application.`,
          category: 'DOCTORS_LIST',
          suggestedQuestions: [
            'Comment prendre rendez-vous ?',
            'Quels sont les horaires de la clinique ?',
          ],
        };
      }
    }

    // 6. Prise de rendez-vous
    if (
      q.includes('rendez-vous') ||
      q.includes('rdv') ||
      q.includes('reserver') ||
      q.includes('réserver') ||
      q.includes('consulter')
    ) {
      return {
        answer:
          'Pour prendre rendez-vous sur l’application mobile :\n1. Rendez-vous dans la section "Mes rendez-vous".\n2. Cliquez sur "Nouveau rendez-vous".\n3. Choisissez votre médecin spécialiste, la date et le créneau souhaité.\n4. Vous recevrez une notification de confirmation dès validation.',
        category: 'APPOINTMENTS',
        suggestedQuestions: [
          'Quels sont les médecins disponibles ?',
          'Quels sont les tarifs ou conventions CNAM ?',
        ],
      };
    }

    // 7. Services et départements
    if (
      q.includes('service') ||
      q.includes('departement') ||
      q.includes('département') ||
      q.includes('bloc') ||
      q.includes('radio') ||
      q.includes('scanner') ||
      q.includes('analyse') ||
      q.includes('labo')
    ) {
      const servicesList = clinic.services.map((s) => `• ${s}`).join('\n');
      return {
        answer: `La ${clinic.name} dispose d'un plateau technique complet comprenant :\n${servicesList}`,
        category: 'SERVICES',
        suggestedQuestions: [
          'Où se trouve la clinique ?',
          'Quels sont les horaires de consultation ?',
        ],
      };
    }

    // 8. Assurances, CNAM, Tarifs
    if (
      q.includes('assurance') ||
      q.includes('cnam') ||
      q.includes('prix') ||
      q.includes('tarif') ||
      q.includes('mutuelle')
    ) {
      return {
        answer:
          'La Polyclinique Arij est conventionnée avec la CNAM ainsi que les principales compagnies d’assurance privées locales et internationales. Pour toute demande de devis ou prise en charge hospitalière, notre bureau des admissions est à votre disposition au standard.',
        category: 'INSURANCE_AND_PRICING',
        suggestedQuestions: [
          'Comment contacter la clinique ?',
          'Comment prendre rendez-vous ?',
        ],
      };
    }

    // Réponse par défaut polyvalente
    return {
      answer: `Bienvenue à la ${clinic.name} ! Je suis votre assistant virtuel. Je peux vous renseigner sur nos médecins spécialistes, nos horaires de consultation, nos services d’urgence ou vous guider pour vos rendez-vous. Comment puis-je vous aider ?`,
      disclaimer: this.medicalDisclaimer,
      category: 'GENERAL_GREETING',
      suggestedQuestions: [
        'Quels sont les horaires de la clinique ?',
        'Quels médecins travaillent en cardiologie ?',
        'Où se trouve la clinique ?',
        'Comment prendre rendez-vous ?',
        'Comment contacter les urgences ?',
      ],
    };
  }

  getSuggestedTopics() {
    return [
      {
        topic: 'Horaires & Urgences',
        question: 'Quels sont les horaires de la clinique et des urgences ?',
      },
      {
        topic: 'Médecins & Spécialités',
        question: 'Quels médecins sont disponibles à la clinique ?',
      },
      {
        topic: 'Prise de rendez-vous',
        question: 'Comment prendre un rendez-vous avec un médecin ?',
      },
      {
        topic: 'Localisation & Parking',
        question: 'Où se trouve la polyclinique à Midoun Djerba ?',
      },
      {
        topic: 'Assurances & CNAM',
        question: 'Quelles sont les conventions d’assurance et CNAM ?',
      },
      {
        topic: 'Plateau technique & Services',
        question: 'Quels sont les services disponibles (Scanner, Bloc, Labo) ?',
      },
    ];
  }
}
