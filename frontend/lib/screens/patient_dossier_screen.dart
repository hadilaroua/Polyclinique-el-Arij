import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dossier/doctor_patient_dossier_screen.dart';
import 'dossier/midwife_patient_dossier_screen.dart';
import 'dossier/nurse_patient_dossier_screen.dart';
import 'dossier/technician_patient_dossier_screen.dart';

export 'dossier/doctor_patient_dossier_screen.dart';
export 'dossier/midwife_patient_dossier_screen.dart';
export 'dossier/nurse_patient_dossier_screen.dart';
export 'dossier/technician_patient_dossier_screen.dart';

/// Écran Dispatcher du Dossier Patient 360°
/// Aiguille automatiquement vers le dossier adapté au rôle de l'utilisateur connecté :
/// - DoctorPatientDossierScreen (Médecins / Praticiens / Admins)
/// - NursePatientDossierScreen (Infirmiers / Soins & Constantes)
/// - MidwifePatientDossierScreen (Sages-Femmes / Maternité & Obstétrique)
/// - TechnicianPatientDossierScreen (Techniciens / Laboratoire & Imagerie)
class PatientDossierScreen extends StatelessWidget {
  final Map<String, dynamic> patient;
  final String? overrideRole;

  const PatientDossierScreen({
    super.key,
    required this.patient,
    this.overrideRole,
  });

  @override
  Widget build(BuildContext context) {
    final role = (overrideRole ?? ApiService().currentUser?['role'] ?? 'DOCTOR')
        .toString()
        .toUpperCase();

    switch (role) {
      case 'NURSE':
      case 'INFIRMIER':
      case 'INFIRMIERE':
        return NursePatientDossierScreen(patient: patient);

      case 'MIDWIFE':
      case 'SAGE_FEMME':
      case 'MATERNITE':
        return MidwifePatientDossierScreen(patient: patient);

      case 'TECHNICIAN':
      case 'TECHNICIEN':
      case 'LABORATOIRE':
      case 'IMAGERIE':
        return TechnicianPatientDossierScreen(patient: patient);

      case 'DOCTOR':
      case 'MEDECIN':
      case 'ADMIN':
      default:
        return DoctorPatientDossierScreen(patient: patient);
    }
  }
}
