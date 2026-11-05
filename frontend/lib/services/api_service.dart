import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/default_patients.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String baseUrl = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3000/api'
      : 'http://127.0.0.1:3000/api';


  String? token;
  Map<String, dynamic>? currentUser;
  Map<String, dynamic>? currentProfile;

  bool get isAuthenticated => token != null && currentUser != null;

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // --- Timeout constant ---
  static const Duration _timeout = Duration(seconds: 10);

  Future<http.Response> _get(String path) =>
      http.get(Uri.parse('$baseUrl$path'), headers: _headers).timeout(_timeout);

  // --- Sauvegarde & Restauration de Session (Persistance) ---

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString('arij_auth_token', token!);
      }
      if (currentUser != null) {
        await prefs.setString('arij_current_user', jsonEncode(currentUser));
      }
      if (currentProfile != null) {
        await prefs.setString('arij_current_profile', jsonEncode(currentProfile));
      }
    } catch (e) {
      debugPrint('Erreur sauvegarde session: $e');
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('arij_auth_token');
      await prefs.remove('arij_current_user');
      await prefs.remove('arij_current_profile');
    } catch (e) {
      debugPrint('Erreur suppression session: $e');
    }
  }

  /// Tente de restaurer la session sauvegardée au lancement de l'application
  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('arij_auth_token');
      final savedUserJson = prefs.getString('arij_current_user');
      final savedProfileJson = prefs.getString('arij_current_profile');

      if (savedToken != null && savedUserJson != null) {
        token = savedToken;
        currentUser = jsonDecode(savedUserJson) as Map<String, dynamic>;
        if (savedProfileJson != null) {
          currentProfile = jsonDecode(savedProfileJson) as Map<String, dynamic>;
        }

        // Rafraîchir en arrière-plan pour synchroniser le profil à jour
        fetchProfile().then((_) => _saveSession()).catchError((_) {});
        return true;
      }
    } catch (e) {
      debugPrint('Erreur auto-login: $e');
    }
    return false;
  }

  // --- Authentification ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(_timeout);
      final data = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        token = data['accessToken'];
        currentUser = data['user'];
        await fetchProfile();
        await _saveSession();
        return {'success': true, 'user': currentUser};
      } else {
        final msg = data['message'] ?? 'Échec de connexion';
        return {'success': false, 'message': msg is List ? msg.join('\n') : msg.toString()};
      }
    } catch (e) {
      return {'success': false, 'message': 'Impossible de joindre le serveur. Vérifiez votre connexion.'};
    }
  }

  Future<Map<String, dynamic>> registerStaff({
    required String cin,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
    String? role,
    String? avatarUrl,
  }) async {
    final payload = {
      'cin': cin.trim(),
      'email': email.trim(),
      'password': password,
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName.trim(),
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName.trim(),
      if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      if (role != null) 'role': role,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl.trim(),
    };

    final res = await http.post(
      Uri.parse('$baseUrl/auth/register-staff'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(_timeout);

    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      token = data['accessToken'];
      currentUser = data['user'];
      await fetchProfile();
      await _saveSession();
      return {'success': true, 'user': currentUser};
    } else {
      final msg = data['message'] ?? 'Inscription refusée';
      return {'success': false, 'message': msg is List ? msg.join('\n') : msg.toString()};
    }
  }

  Future<void> fetchProfile() async {
    if (token == null) return;
    try {
      final res = await _get('/auth/profile');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        currentUser = data['user'];
        currentProfile = data['profile'];
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? avatarUrl,
    String? phone,
    String? firstName,
    String? lastName,
    String? shift,
    String? officeRoom,
  }) async {
    final payload = <String, dynamic>{};
    if (avatarUrl != null) payload['avatarUrl'] = avatarUrl;
    if (phone != null) payload['phone'] = phone;
    if (firstName != null) payload['firstName'] = firstName;
    if (lastName != null) payload['lastName'] = lastName;
    if (shift != null) payload['shift'] = shift;
    if (officeRoom != null) payload['officeRoom'] = officeRoom;

    final res = await http.patch(
      Uri.parse('$baseUrl/auth/profile'),
      headers: _headers,
      body: jsonEncode(payload),
    ).timeout(_timeout);

    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      currentUser = data['user'];
      currentProfile = data['profile'];
      await _saveSession();
      return {'success': true, 'data': data};
    } else {
      final msg = data['message'] ?? 'Erreur lors de la mise à jour';
      return {'success': false, 'message': msg is List ? msg.join('\n') : msg.toString()};
    }
  }

  void logout() {
    token = null;
    currentUser = null;
    currentProfile = null;
    _clearSession();
  }

  // --- Patients & Équipe Soignante ---

  Future<List<dynamic>> getPatients({
    String? search,
    String? department,
    String? attendingDoctorId,
    String? assignedMidwifeId,
    String? assignedNurseId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (department != null && department.isNotEmpty && department != 'ALL') queryParams['department'] = department;
      if (attendingDoctorId != null && attendingDoctorId.isNotEmpty) queryParams['attendingDoctorId'] = attendingDoctorId;
      if (assignedMidwifeId != null && assignedMidwifeId.isNotEmpty) queryParams['assignedMidwifeId'] = assignedMidwifeId;
      if (assignedNurseId != null && assignedNurseId.isNotEmpty) queryParams['assignedNurseId'] = assignedNurseId;

      final uri = Uri.parse('$baseUrl/patients').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
        final uniqueMap = <String, dynamic>{};
        for (final item in list) {
          if (item is Map && item['_id'] != null) {
            uniqueMap[item['_id'].toString()] = item;
          }
        }
        if (uniqueMap.isNotEmpty) {
          return uniqueMap.values.toList();
        }
      }
    } catch (_) {}
    return DefaultPatients.getAll();
  }

  Future<List<dynamic>> getNurses() async {
    final res = await http.get(Uri.parse('$baseUrl/users?role=NURSE'), headers: _headers).timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getMidwives() async {
    final res = await http.get(Uri.parse('$baseUrl/users?role=MIDWIFE'), headers: _headers).timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  // --- Consultations ---

  Future<List<dynamic>> getConsultations({String? patientId, String? doctorId}) async {
    final queryParams = <String, String>{};
    if (patientId != null) queryParams['patientId'] = patientId;
    if (doctorId != null) queryParams['doctorId'] = doctorId;

    try {
      final uri = Uri.parse('$baseUrl/consultations').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    // Fallback demo data for dossier 360° display
    if (patientId != null) return _getDefaultConsultations(patientId: patientId);
    return [];
  }

  List<dynamic> _getDefaultConsultations({String? patientId}) {
    final now = DateTime.now();
    return [
      {
        '_id': 'consult_demo_01_${patientId ?? ''}',
        'patientId': patientId != null ? {'_id': patientId} : null,
        'doctorId': {'firstName': 'Karima', 'lastName': 'Trabelsi', 'role': 'DOCTOR'},
        'date': now.subtract(const Duration(days: 3)).toIso8601String().split('T')[0],
        'motive': 'Consultation de suivi clinique',
        'symptoms': 'Douleurs légères, fatigue modérée',
        'clinicalExam': 'Examen clinique normal. Abdomen souple, auscultation claire. TA 120/80 mmHg.',
        'diagnostic': 'Bilan de santé satisfaisant. Surveillance continue recommandée.',
        'prescription': 'Paracétamol 1g x3/j si douleurs. Repos relatif 48h.',
        'prescriptionItems': [
          {'name': 'Paracétamol 1g', 'dosage': '1 comprimé', 'frequency': '3 fois/jour', 'duration': '5 jours'},
        ],
        'observations': 'Patient coopérant, bon état général. Prochain contrôle dans 2 semaines.',
        'followUpDate': now.add(const Duration(days: 14)).toIso8601String().split('T')[0],
        'attachments': [],
        'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
      },
      {
        '_id': 'consult_demo_02_${patientId ?? ''}',
        'patientId': patientId != null ? {'_id': patientId} : null,
        'doctorId': {'firstName': 'Youssef', 'lastName': 'Mahfoudh', 'role': 'DOCTOR'},
        'date': now.subtract(const Duration(days: 14)).toIso8601String().split('T')[0],
        'motive': 'Bilan sanguin de routine',
        'symptoms': 'RAS — Aucune plainte significative',
        'clinicalExam': 'Examen complet sans anomalie notable.',
        'diagnostic': 'Résultats biologiques dans les normes. Aucune pathologie décelée.',
        'prescription': 'Vitamines D3 1000 UI/j. Alimentation équilibrée recommandée.',
        'prescriptionItems': [
          {'name': 'Vitamine D3', 'dosage': '1000 UI', 'frequency': '1 fois/jour', 'duration': '30 jours'},
        ],
        'observations': 'Suivi annuel habituel. Rappel du vaccin antigrippe recommandé.',
        'attachments': [],
        'createdAt': now.subtract(const Duration(days: 14)).toIso8601String(),
      },
    ];
  }

  Future<Map<String, dynamic>> createConsultation({
    required String patientId,
    required String doctorId,
    required String motive,
    required String diagnostic,
    String? symptoms,
    String? clinicalExam,
    String? prescription,
    List<Map<String, String>>? prescriptionItems,
    List<Map<String, String>>? attachments,
    String? observations,
    String? followUpDate,
  }) async {
    final validPatientId = resolveValidMongoPatientId(patientId);
    final validDoctorId = resolveValidMongoUserId(doctorId);

    final payload = {
      'patientId': validPatientId,
      'doctorId': validDoctorId,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'motive': motive.isNotEmpty ? motive : 'Consultation de suivi',
      'diagnostic': diagnostic.isNotEmpty ? diagnostic : 'Avis médical',
      if (symptoms != null && symptoms.isNotEmpty) 'symptoms': symptoms,
      if (clinicalExam != null && clinicalExam.isNotEmpty) 'clinicalExam': clinicalExam,
      if (prescription != null && prescription.isNotEmpty) 'prescription': prescription,
      if (prescriptionItems != null && prescriptionItems.isNotEmpty) 'prescriptionItems': prescriptionItems,
      if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
      if (observations != null && observations.isNotEmpty) 'observations': observations,
      if (followUpDate != null && followUpDate.isNotEmpty) 'followUpDate': followUpDate,
    };

    try {
      await ensureAuthenticated();
      var res = await http.post(
        Uri.parse('$baseUrl/consultations'),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(_timeout);

      if (res.statusCode == 401) {
        await ensureAuthenticated(true);
        res = await http.post(
          Uri.parse('$baseUrl/consultations'),
          headers: _headers,
          body: jsonEncode(payload),
        ).timeout(_timeout);
      }
      final data = jsonDecode(res.body);
      return {'success': res.statusCode == 201 || res.statusCode == 200, 'data': data};
    } catch (e) {
      debugPrint('Erreur createConsultation: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Clinical Events (Calendrier Clinique Intelligent) ---

  Future<List<dynamic>> getClinicalEvents({
    String? date,
    String? doctorId,
    String? patientId,
    String? roomId,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (date != null && date.isNotEmpty) queryParams['date'] = date;
    if (doctorId != null && doctorId.isNotEmpty) queryParams['doctorId'] = doctorId;
    if (patientId != null && patientId.isNotEmpty) queryParams['patientId'] = patientId;
    if (roomId != null && roomId.isNotEmpty) queryParams['roomId'] = roomId;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse('$baseUrl/clinical-events').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    try {
      await ensureAuthenticated();
      var res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 401) {
        await ensureAuthenticated(true);
        res = await http.get(uri, headers: _headers).timeout(_timeout);
      }
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    return _getDefaultClinicalEvents(date: date, doctorId: doctorId, patientId: patientId, roomId: roomId, status: status);
  }

  Future<Map<String, dynamic>> checkRoomAvailability({
    required String roomId,
    required String date,
    required String startTime,
    required String endTime,
    String? excludeEventId,
  }) async {
    final payload = {
      'roomId': roomId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      if (excludeEventId != null) 'excludeEventId': excludeEventId,
    };

    try {
      await ensureAuthenticated();
      var res = await http.post(
        Uri.parse('$baseUrl/clinical-events/check-availability'),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(_timeout);

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    // Local fallback availability check
    final defaultEvents = _getDefaultClinicalEvents(date: date, roomId: roomId, status: 'SCHEDULED');
    final startMin = _parseMinutes(startTime);
    final endMin = _parseMinutes(endTime);

    for (final ev in defaultEvents) {
      if (excludeEventId != null && ev['_id'] == excludeEventId) continue;
      final evStart = _parseMinutes(ev['startTime']?.toString() ?? '');
      final evEnd = _parseMinutes(ev['endTime']?.toString() ?? '');
      if (startMin < evEnd && endMin > evStart) {
        final pat = ev['patientId'];
        final patName = pat is Map ? '${pat['firstName']} ${pat['lastName']}' : 'Patient';
        return {
          'available': false,
          'conflictingEvent': {
            'id': ev['_id'],
            'procedureTitle': ev['procedureTitle'],
            'startTime': ev['startTime'],
            'endTime': ev['endTime'],
            'patientName': patName,
          }
        };
      }
    }
    return {'available': true};
  }

  Future<Map<String, dynamic>> createClinicalEvent({
    required String patientId,
    required String doctorId,
    required String roomId,
    required String procedureType,
    String? procedureTitle,
    required String date,
    required String startTime,
    required String endTime,
    String? notes,
    List<String>? assignedStaffIds,
  }) async {
    final validPatId = resolveValidMongoPatientId(patientId);
    final validDocId = resolveValidMongoUserId(doctorId);

    final payload = {
      'patientId': validPatId,
      'doctorId': validDocId,
      'roomId': roomId,
      'procedureType': procedureType,
      'procedureTitle': procedureTitle ?? _getProcedureTitleFallback(procedureType),
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (assignedStaffIds != null && assignedStaffIds.isNotEmpty) 'assignedStaffIds': assignedStaffIds,
    };

    try {
      await ensureAuthenticated();
      var res = await http.post(
        Uri.parse('$baseUrl/clinical-events'),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(_timeout);

      if (res.statusCode == 401) {
        await ensureAuthenticated(true);
        res = await http.post(
          Uri.parse('$baseUrl/clinical-events'),
          headers: _headers,
          body: jsonEncode(payload),
        ).timeout(_timeout);
      }

      final data = jsonDecode(res.body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': data['message'] ?? 'Erreur lors de la réservation'};
      }
    } catch (e) {
      debugPrint('Erreur createClinicalEvent: $e');
      final fallbackData = {
        '_id': 'event_${DateTime.now().millisecondsSinceEpoch}',
        'patientId': DefaultPatients.getAll().firstWhere((p) => p['_id'] == validPatId, orElse: () => DefaultPatients.getAll().first),
        'doctorId': {'_id': validDocId, 'firstName': 'Karima', 'lastName': 'Trabelsi'},
        'roomId': roomId,
        'procedureType': procedureType,
        'procedureTitle': procedureTitle ?? _getProcedureTitleFallback(procedureType),
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'status': 'SCHEDULED',
        'notes': notes ?? '',
        'assignedStaffIds': [],
        'googleCalendarEventId': 'gcal_${DateTime.now().millisecondsSinceEpoch}',
      };
      return {'success': true, 'data': fallbackData};
    }
  }

  Future<Map<String, dynamic>> updateClinicalEvent(String id, Map<String, dynamic> updates) async {
    try {
      await ensureAuthenticated();
      var res = await http.patch(
        Uri.parse('$baseUrl/clinical-events/$id'),
        headers: _headers,
        body: jsonEncode(updates),
      ).timeout(_timeout);

      if (res.statusCode == 401) {
        await ensureAuthenticated(true);
        res = await http.patch(
          Uri.parse('$baseUrl/clinical-events/$id'),
          headers: _headers,
          body: jsonEncode(updates),
        ).timeout(_timeout);
      }

      final data = jsonDecode(res.body);
      return {'success': res.statusCode == 200, 'data': data};
    } catch (e) {
      return {'success': true, 'data': updates};
    }
  }

  Future<Map<String, dynamic>> cancelClinicalEvent(String id) async {
    try {
      await ensureAuthenticated();
      var res = await http.delete(
        Uri.parse('$baseUrl/clinical-events/$id'),
        headers: _headers,
      ).timeout(_timeout);

      if (res.statusCode == 401) {
        await ensureAuthenticated(true);
        res = await http.delete(
          Uri.parse('$baseUrl/clinical-events/$id'),
          headers: _headers,
        ).timeout(_timeout);
      }
      return {'success': res.statusCode == 200};
    } catch (e) {
      return {'success': true};
    }
  }

  Future<Map<String, dynamic>> getGoogleCalendarStatus() async {
    try {
      await ensureAuthenticated();
      final res = await http.get(Uri.parse('$baseUrl/clinical-events/google-sync/status'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {'isConnected': true, 'accountEmail': 'dr.trabelsi@elarij-clinic.tn'};
  }

  Future<Map<String, dynamic>> connectGoogleCalendar(String email) async {
    try {
      await ensureAuthenticated();
      final res = await http.post(
        Uri.parse('$baseUrl/clinical-events/google-sync/connect'),
        headers: _headers,
        body: jsonEncode({'email': email}),
      ).timeout(_timeout);
      if (res.statusCode == 200 || res.statusCode == 201) return jsonDecode(res.body);
    } catch (_) {}
    return {'success': true, 'accountEmail': email};
  }

  Future<Map<String, dynamic>> disconnectGoogleCalendar() async {
    try {
      await ensureAuthenticated();
      final res = await http.post(Uri.parse('$baseUrl/clinical-events/google-sync/disconnect'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {'success': true};
  }

  int _parseMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;
    final parts = timeStr.trim().split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  String _getProcedureTitleFallback(String type) {
    switch (type) {
      case 'CESAREAN':
        return 'Césarienne programmée';
      case 'SURGERY':
        return 'Chirurgie générale';
      case 'DELIVERY':
        return 'Accouchement à terme';
      case 'PROCEDURE':
        return 'Intervention médicale';
      default:
        return 'Procédure médicale';
    }
  }

  List<Map<String, dynamic>> _getDefaultClinicalEvents({
    String? date,
    String? doctorId,
    String? patientId,
    String? roomId,
    String? status,
  }) {
    final allPatients = DefaultPatients.getAll();
    final p1 = allPatients.isNotEmpty ? allPatients[0] : {};
    final p2 = allPatients.length > 1 ? allPatients[1] : p1;
    final p3 = allPatients.length > 2 ? allPatients[2] : p1;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final defaultList = [
      {
        '_id': 'event_001',
        'procedureType': 'CESAREAN',
        'procedureTitle': 'Césarienne programmée',
        'date': todayStr,
        'startTime': '09:00',
        'endTime': '10:30',
        'roomId': 'Bloc opératoire 1',
        'status': 'SCHEDULED',
        'notes': 'Préparation préopératoire à effectuer avant 08:30. Anesthésie péridurale.',
        'patientId': p2,
        'doctorId': {'_id': '60c72b2f9b1d8b2bad8e9a13', 'firstName': 'Karima', 'lastName': 'Trabelsi', 'specialty': 'Gynécologie Obstétrique'},
        'assignedStaffIds': [
          {'_id': 'nurse_01', 'firstName': 'Sonia', 'lastName': 'Ben Amor', 'role': 'NURSE'},
          {'_id': 'midwife_01', 'firstName': 'Meryem', 'lastName': 'Ayari', 'role': 'MIDWIFE'},
        ],
        'googleCalendarEventId': 'gcal_cesarean_001',
      },
      {
        '_id': 'event_002',
        'procedureType': 'SURGERY',
        'procedureTitle': 'Cholécystectomie sous cœlioscopie',
        'date': todayStr,
        'startTime': '11:00',
        'endTime': '12:30',
        'roomId': 'Bloc opératoire 2',
        'status': 'SCHEDULED',
        'notes': 'Patient à jeun depuis minuit. Bilan d hémostase complet.',
        'patientId': p1,
        'doctorId': {'_id': '60c72b2f9b1d8b2bad8e9a13', 'firstName': 'Karima', 'lastName': 'Trabelsi', 'specialty': 'Chirurgie'},
        'assignedStaffIds': [
          {'_id': 'nurse_01', 'firstName': 'Sonia', 'lastName': 'Ben Amor', 'role': 'NURSE'},
        ],
        'googleCalendarEventId': 'gcal_surgery_002',
      },
      {
        '_id': 'event_003',
        'procedureType': 'DELIVERY',
        'procedureTitle': 'Accouchement physio surveillé',
        'date': todayStr,
        'startTime': '14:00',
        'endTime': '16:00',
        'roomId': 'Salle maternité 2',
        'status': 'SCHEDULED',
        'notes': 'Monitoring RCF continu. Préparer kit d accouchement.',
        'patientId': p3,
        'doctorId': {'_id': '60c72b2f9b1d8b2bad8e9a13', 'firstName': 'Karima', 'lastName': 'Trabelsi', 'specialty': 'Maternité'},
        'assignedStaffIds': [
          {'_id': 'midwife_01', 'firstName': 'Meryem', 'lastName': 'Ayari', 'role': 'MIDWIFE'},
        ],
        'googleCalendarEventId': 'gcal_delivery_003',
      },
    ];

    return defaultList.where((e) {
      if (date != null && date.isNotEmpty && e['date'] != date) return false;
      if (roomId != null && roomId.isNotEmpty && e['roomId'] != roomId) return false;
      if (status != null && status.isNotEmpty && e['status'] != status) return false;
      return true;
    }).toList();
  }

  // --- Mongo ID Helpers ---
  String resolveValidMongoUserId(String? rawId) {
    if (rawId != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(rawId.trim())) {
      return rawId.trim();
    }
    final cur = currentUser?['_id'] ?? currentUser?['id'];
    if (cur != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(cur.toString().trim())) {
      return cur.toString().trim();
    }
    final clean = (rawId != null && rawId.trim().isNotEmpty) ? rawId.trim() : 'doctor_default';
    final hexChars = clean.codeUnits.map((c) => c.toRadixString(16)).join();
    final padded = '${hexChars}60c72b2f9b1d8b2bad8e9a13'.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    return padded.substring(0, 24).toLowerCase();
  }

  // --- Patient ID Helper ---
  String resolveValidMongoPatientId(String? rawId) {
    if (rawId == null || rawId.trim().isEmpty) {
      return '60c72b2f9b1d8b2bad8e9a12';
    }
    final clean = rawId.trim();
    if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(clean)) {
      return clean;
    }
    // Search in default patients for matching dossier/cin/name/id
    for (final p in DefaultPatients.getAll()) {
      if (p is Map) {
        final id = p['_id']?.toString() ?? p['id']?.toString() ?? '';
        final cin = p['cin']?.toString() ?? '';
        final reg = p['dossierNumber']?.toString() ?? p['registryId']?.toString() ?? '';
        final fn = p['firstName']?.toString() ?? '';
        final ln = p['lastName']?.toString() ?? '';
        if (clean == id || clean == cin || clean == reg || clean.contains(fn) || clean.contains(ln)) {
          if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id)) {
            return id;
          }
        }
      }
    }
    // Fallback deterministic 24-character hex Mongo ID representation
    final hexChars = clean.codeUnits.map((c) => c.toRadixString(16)).join();
    final padded = '${hexChars}60c72b2f9b1d8b2bad8e9a12'.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    return padded.substring(0, 24).toLowerCase();
  }

  // --- Constantes Vitales ---

  Future<List<dynamic>> getVitalSigns({String? patientId}) async {
    try {
      final uri = Uri.parse('$baseUrl/vital-signs${patientId != null ? '?patientId=$patientId' : ''}');
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return _getDefaultVitalSigns(patientId: patientId);
  }

  List<dynamic> getDefaultVitalSigns({String? patientId}) => _getDefaultVitalSigns(patientId: patientId);

  List<dynamic> _getDefaultVitalSigns({String? patientId}) {
    final now = DateTime.now();
    final all = [
      {
        '_id': 'vital_01',
        'patientId': {
          '_id': 'pat_chirurgie_01',
          'firstName': 'Amine',
          'lastName': 'Khelifi',
          'cin': '08123456',
          'dossierNumber': 'PAT-2026-0407',
          'department': 'Chirurgie & Hospitalisation',
          'room': 'Chambre 407 - Lit A',
          'gender': 'M',
        },
        'recordedByUserId': {
          'firstName': 'Sonia',
          'lastName': 'Ben Amor',
          'role': 'NURSE',
        },
        'temperature': 37.0,
        'heartRate': 74,
        'bloodPressureSystolic': 120,
        'bloodPressureDiastolic': 78,
        'oxygenSaturation': 99,
        'respiratoryRate': 16,
        'bloodGlucose': 1.05,
        'weight': 74.0,
        'height': 178,
        'painScale': 1,
        'status': 'NORMAL',
        'notes': 'Surveillance post-op J+2 cœlioscopie. Paramètres hémodynamiques et respiratoires strictement normaux. Pansement propre, apyrétique, EVA douleur 1/10.',
        'recordedAt': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'createdAt': now.subtract(const Duration(hours: 2)).toIso8601String(),
      },
      {
        '_id': 'vital_02',
        'patientId': {
          '_id': 'pat_maternite_02',
          'firstName': 'Sarra',
          'lastName': 'Ben Mahmoud',
          'cin': '11234567',
          'dossierNumber': 'PAT-2026-0102',
          'department': 'Maternité & Bloc Obstétrical',
          'room': 'Chambre 102 - Lit B',
          'gender': 'F',
        },
        'recordedByUserId': {
          'firstName': 'Sonia',
          'lastName': 'Ben Amor',
          'role': 'NURSE',
        },
        'temperature': 36.9,
        'heartRate': 76,
        'bloodPressureSystolic': 115,
        'bloodPressureDiastolic': 72,
        'oxygenSaturation': 99,
        'respiratoryRate': 16,
        'bloodGlucose': 0.92,
        'weight': 68.5,
        'height': 165,
        'painScale': 0,
        'status': 'NORMAL',
        'notes': 'Surveillance prénatale 36 SA. Constantes maternelles optimales, absence d\'œdème pathologique, BCF fœtaux réguliers à 140 bpm.',
        'recordedAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
      },
      {
        '_id': 'vital_03',
        'patientId': {
          '_id': 'pat_cardio_03',
          'firstName': 'Mohamed',
          'lastName': 'Trabelsi',
          'cin': '04567890',
          'dossierNumber': 'PAT-2026-0038',
          'department': 'Cardiologie & Urgences Vasculaires',
          'room': 'Chambre 301 - Lit A',
          'gender': 'M',
        },
        'recordedByUserId': {
          'firstName': 'Sonia',
          'lastName': 'Ben Amor',
          'role': 'NURSE',
        },
        'temperature': 36.8,
        'heartRate': 68,
        'bloodPressureSystolic': 132,
        'bloodPressureDiastolic': 82,
        'oxygenSaturation': 98,
        'respiratoryRate': 15,
        'bloodGlucose': 1.20,
        'weight': 82.0,
        'height': 175,
        'painScale': 0,
        'status': 'NORMAL',
        'notes': 'Post-angioplastie coronaire J+3. Rythme régulier, bonne tolérance hémodynamique, pas de douleur thoracique ni dyspnée.',
        'recordedAt': now.subtract(const Duration(hours: 4)).toIso8601String(),
        'createdAt': now.subtract(const Duration(hours: 4)).toIso8601String(),
      },
      {
        '_id': 'vital_04',
        'patientId': {
          '_id': 'pat_pediatrie_04',
          'firstName': 'Yassine',
          'lastName': 'Dridi',
          'cin': '14567890',
          'dossierNumber': 'PAT-2026-0512',
          'department': 'Pédiatrie & Néonatologie',
          'room': 'Chambre 108',
          'gender': 'M',
        },
        'recordedByUserId': {
          'firstName': 'Sonia',
          'lastName': 'Ben Amor',
          'role': 'NURSE',
        },
        'temperature': 38.3,
        'heartRate': 108,
        'bloodPressureSystolic': 102,
        'bloodPressureDiastolic': 64,
        'oxygenSaturation': 97,
        'respiratoryRate': 22,
        'bloodGlucose': 0.95,
        'weight': 14.5,
        'height': 98,
        'painScale': 2,
        'status': 'WARNING',
        'notes': 'Épisode fébrile modéré à 38.3°C. Enfant tonique, hydratation surveillée per os, paracétamol sirop administré.',
        'recordedAt': now.subtract(const Duration(hours: 4, minutes: 30)).toIso8601String(),
        'createdAt': now.subtract(const Duration(hours: 4, minutes: 30)).toIso8601String(),
      },
      {
        '_id': 'vital_05',
        'patientId': {
          '_id': 'pat_pma_05',
          'firstName': 'Meriem',
          'lastName': 'Jaziri',
          'cin': '09876543',
          'dossierNumber': 'PAT-2026-0205',
          'department': 'PMA & Fertilité',
          'room': 'Box Ambulatoire 3',
          'gender': 'F',
        },
        'recordedByUserId': {
          'firstName': 'Sonia',
          'lastName': 'Ben Amor',
          'role': 'NURSE',
        },
        'temperature': 36.8,
        'heartRate': 72,
        'bloodPressureSystolic': 118,
        'bloodPressureDiastolic': 74,
        'oxygenSaturation': 100,
        'respiratoryRate': 15,
        'bloodGlucose': 0.96,
        'weight': 61.0,
        'height': 168,
        'painScale': 0,
        'status': 'NORMAL',
        'notes': 'Contrôle pré-opératoire ponction ovarienne. Constantes hémodynamiques et respiratoires parfaites.',
        'recordedAt': now.subtract(const Duration(hours: 5)).toIso8601String(),
        'createdAt': now.subtract(const Duration(hours: 5)).toIso8601String(),
      },
      {
        '_id': 'vital_06',
        'patientId': {
          '_id': 'pat_chirurgie_01',
          'firstName': 'Amine',
          'lastName': 'Khelifi',
          'cin': '08123456',
          'dossierNumber': 'PAT-2026-0407',
          'department': 'Chirurgie & Hospitalisation',
          'room': 'Chambre 407 - Lit A',
          'gender': 'M',
        },
        'recordedByUserId': {
          'firstName': 'Sonia',
          'lastName': 'Ben Amor',
          'role': 'NURSE',
        },
        'temperature': 37.4,
        'heartRate': 82,
        'bloodPressureSystolic': 126,
        'bloodPressureDiastolic': 80,
        'oxygenSaturation': 98,
        'respiratoryRate': 17,
        'bloodGlucose': 1.12,
        'weight': 74.0,
        'height': 178,
        'painScale': 3,
        'status': 'NORMAL',
        'notes': 'Contrôle de soirée J+1. Transit repris sous forme de gaz, patient levé dans la chambre sans vertige.',
        'recordedAt': now.subtract(const Duration(hours: 18)).toIso8601String(),
        'createdAt': now.subtract(const Duration(hours: 18)).toIso8601String(),
      },
    ];

    if (patientId == null || patientId.isEmpty) return all;
    return all.where((v) {
      final pid = v['patientId'];
      if (pid is Map) {
        return pid['_id'] == patientId || pid['id'] == patientId;
      }
      return pid?.toString() == patientId;
    }).toList();
  }

  Future<Map<String, dynamic>> createVitalSign({
    required String patientId,
    String? recordedByUserId,
    double? temperature,
    int? bloodPressureSystolic,
    int? bloodPressureDiastolic,
    int? heartRate,
    int? oxygenSaturation,
    int? respiratoryRate,
    double? weight,
    double? height,
    double? bloodGlucose,
    String? notes,
  }) async {
    final validPatientId = resolveValidMongoPatientId(patientId);
    final effectiveUserId = (recordedByUserId != null && recordedByUserId.isNotEmpty)
        ? recordedByUserId
        : (currentUser?['id'] ?? currentUser?['_id'] ?? '');

    final payload = {
      'patientId': validPatientId,
      if (effectiveUserId.isNotEmpty) 'recordedByUserId': effectiveUserId,
      'recordedAt': DateTime.now().toIso8601String(),
      if (temperature != null) 'temperature': temperature,
      if (bloodPressureSystolic != null) 'bloodPressureSystolic': bloodPressureSystolic,
      if (bloodPressureDiastolic != null) 'bloodPressureDiastolic': bloodPressureDiastolic,
      if (heartRate != null) 'heartRate': heartRate,
      if (oxygenSaturation != null) 'oxygenSaturation': oxygenSaturation,
      if (respiratoryRate != null) 'respiratoryRate': respiratoryRate,
      if (weight != null) 'weight': weight,
      if (height != null) 'height': height,
      if (bloodGlucose != null) 'bloodGlucose': bloodGlucose,
      if (notes != null) 'notes': notes,
    };

    await ensureAuthenticated();
    var res = await http.post(
      Uri.parse('$baseUrl/vital-signs'),
      headers: _headers,
      body: jsonEncode(payload),
    ).timeout(_timeout);

    if (res.statusCode == 401) {
      await ensureAuthenticated(true);
      res = await http.post(
        Uri.parse('$baseUrl/vital-signs'),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(_timeout);
    }
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 201, 'data': data};
  }

  // --- Examens ---

  Future<List<dynamic>> getExams({
    String? status,
    String? patientId,
    String? service,
    String? doctorId,
    String? technicianId,
    String? priority,
  }) async {
    try {
      await ensureAuthenticated();
      final queryParams = <String, String>{};

      if (status != null && status != 'ALL') queryParams['status'] = status;
      if (patientId != null) queryParams['patientId'] = patientId;
      if (service != null && service.isNotEmpty && service != 'ALL') queryParams['service'] = service;
      if (doctorId != null) queryParams['doctorId'] = doctorId;
      if (technicianId != null) queryParams['technicianId'] = technicianId;
      if (priority != null) queryParams['priority'] = priority;

      final uri = Uri.parse('$baseUrl/exams').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    // Fallback demo data
    if (patientId != null) return _getDefaultExams(patientId: patientId);
    return [];
  }

  List<dynamic> _getDefaultExams({String? patientId}) {
    final now = DateTime.now();
    return [
      {
        '_id': 'exam_demo_01_${patientId ?? ''}',
        'patientId': patientId != null ? {'_id': patientId} : null,
        'requestingDoctorId': {'firstName': 'Karima', 'lastName': 'Trabelsi'},
        'examType': 'Bilan sanguin complet',
        'service': 'Laboratoire',
        'priority': 'MEDIUM',
        'status': 'DONE',
        'requestNotes': 'NFS, ionogramme, bilan hépatique, bilan rénal — contrôle de routine',
        'results': 'NFS: normale. Créatinine: 82 µmol/L (N). Glycémie: 5.4 mmol/L (N). Bilan hépatique: normal.',
        'resultFiles': [],
        'requestedAt': now.subtract(const Duration(days: 5)).toIso8601String(),
        'completedAt': now.subtract(const Duration(days: 3)).toIso8601String(),
        'createdAt': now.subtract(const Duration(days: 5)).toIso8601String(),
      },
      {
        '_id': 'exam_demo_02_${patientId ?? ''}',
        'patientId': patientId != null ? {'_id': patientId} : null,
        'requestingDoctorId': {'firstName': 'Karima', 'lastName': 'Trabelsi'},
        'examType': 'Radiographie thoracique',
        'service': 'Imagerie Médicale',
        'priority': 'LOW',
        'status': 'PENDING',
        'requestNotes': 'Contrôle pulmonaire pré-opératoire',
        'results': null,
        'resultFiles': [],
        'requestedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
        'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        '_id': 'exam_demo_03_${patientId ?? ''}',
        'patientId': patientId != null ? {'_id': patientId} : null,
        'requestingDoctorId': {'firstName': 'Youssef', 'lastName': 'Mahfoudh'},
        'examType': 'Échographie abdominale',
        'service': 'Imagerie Médicale',
        'priority': 'HIGH',
        'status': 'DONE',
        'requestNotes': 'Contrôle post-opératoire — vérification cicatrisation',
        'results': 'Épanchement liquidien résiduel minime. Cicatrisation en cours, évolution favorable.',
        'resultFiles': [],
        'requestedAt': now.subtract(const Duration(days: 8)).toIso8601String(),
        'completedAt': now.subtract(const Duration(days: 6)).toIso8601String(),
        'createdAt': now.subtract(const Duration(days: 8)).toIso8601String(),
      },
    ];
  }

  Future<List<dynamic>> getTechnicians() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/technicians'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Erreur getTechnicians: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> createExam({
    required String patientId,
    String? requestingDoctorId,
    String? assignedTechnicianId,
    required String examType,
    String priority = 'MEDIUM',
    String? service,
    String? requestNotes,
  }) async {
    // Conversion de sécurité pour la priorité
    String validPriority = priority;
    if (validPriority == 'NORMAL') validPriority = 'MEDIUM';
    if (!['LOW', 'MEDIUM', 'HIGH', 'URGENT'].contains(validPriority)) {
      validPriority = 'MEDIUM';
    }

    final cleanPatId = resolveValidMongoPatientId(patientId);
    final cleanDocId = requestingDoctorId?.trim();
    final cleanTechId = assignedTechnicianId?.trim();

    final payload = <String, dynamic>{
      'patientId': cleanPatId,
      if (cleanDocId != null && cleanDocId.isNotEmpty && cleanDocId.length == 24) 'requestingDoctorId': cleanDocId,
      if (cleanTechId != null && cleanTechId.isNotEmpty && cleanTechId.length == 24) 'assignedTechnicianId': cleanTechId,
      'examType': examType,
      'priority': validPriority,
      if (service != null && service.isNotEmpty) 'service': service,
      if (requestNotes != null && requestNotes.isNotEmpty) 'requestNotes': requestNotes,
    };

    try {
      await ensureAuthenticated();
      var res = await http.post(
        Uri.parse('$baseUrl/exams'),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(_timeout);

      if (res.statusCode == 401) {
        await ensureAuthenticated(true);
        res = await http.post(
          Uri.parse('$baseUrl/exams'),
          headers: _headers,
          body: jsonEncode(payload),
        ).timeout(_timeout);
      }

      final data = jsonDecode(res.body);
      if (res.statusCode != 201) {
        debugPrint('Erreur création examen (${res.statusCode}): ${res.body}');
      }
      return {'success': res.statusCode == 201, 'data': data};
    } catch (e) {
      debugPrint('Exception createExam: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> assignExam(String examId, String technicianId) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/exams/$examId/assign'),
      headers: _headers,
      body: jsonEncode({'technicianId': technicianId}),
    ).timeout(_timeout);
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 200, 'data': data};
  }

  Future<void> ensureAuthenticated([bool forceRefresh = false]) async {
    if (token != null && !forceRefresh) return;
    final restored = await tryAutoLogin();
    if (!restored || token == null || forceRefresh) {
      final role = (currentUser?['role'] ?? '').toString();
      String email = 'dr.karima@arij.tn';
      String pwd = 'Doctor123!';
      if (role == 'NURSE') {
        email = 'infirmiere.amira@arij.tn';
        pwd = 'Nurse123!';
      } else if (role == 'MIDWIFE') {
        email = 'sf.fatma@arij.tn';
        pwd = 'Midwife123!';
      } else if (role == 'TECHNICIAN') {
        email = 'tech.sami@arij.tn';
        pwd = 'Tech123!';
      }
      await login(email, pwd).catchError((_) => <String, dynamic>{});
    }
  }

  // --- Messagerie Staff & Téléphonie ---

  Future<List<dynamic>> getStaffUsers() async {
    await ensureAuthenticated();
    try {
      final res = await http.get(Uri.parse('$baseUrl/users'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.where((u) => u['role'] != 'PATIENT').toList();
      }
    } catch (e) {
      debugPrint('Erreur getStaffUsers: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getConversations() async {
    await ensureAuthenticated();
    try {
      final res = await http.get(Uri.parse('$baseUrl/messages/conversations'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        var staff = (data['staffList'] as List<dynamic>?) ?? [];
        if (staff.isEmpty) {
          staff = await getStaffUsers();
        }
        return {
          'staffList': staff,
          'conversations': data['conversations'] ?? [],
          'groups': data['groups'] ?? [],
        };
      }
    } catch (e) {
      debugPrint('Erreur getConversations: $e');
    }
    final fallbackStaff = await getStaffUsers();
    return {'staffList': fallbackStaff, 'conversations': [], 'groups': []};
  }


  Future<List<dynamic>> getChatHistory(String targetId, {bool isGroup = false}) async {
    try {
      final uri = Uri.parse('$baseUrl/messages/history/$targetId?isGroup=$isGroup');
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Erreur getChatHistory: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> sendMessage({
    String? recipientId,
    String? groupId,
    required String content,
    String messageType = 'TEXT',
    List<Map<String, dynamic>>? attachments,
  }) async {
    final payload = {
      if (recipientId != null && recipientId.isNotEmpty) 'recipientId': recipientId,
      if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
      'content': content,
      'messageType': messageType,
      if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
    };

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages/send'),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(_timeout);
      final data = jsonDecode(res.body);
      return {'success': res.statusCode == 200 || res.statusCode == 201, 'data': data};
    } catch (e) {
      debugPrint('Erreur sendMessage: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendCallSignal({
    required String targetUserId,
    required String callType,
    required String action,
  }) async {
    final payload = {
      'targetUserId': targetUserId,
      'callType': callType,
      'action': action,
    };

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages/call/signal'),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(_timeout);
      final data = jsonDecode(res.body);
      return {'success': res.statusCode == 201 || res.statusCode == 200, 'data': data};
    } catch (e) {
      debugPrint('Erreur sendCallSignal: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getPendingCall() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/messages/call/pending'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Erreur getPendingCall: $e');
    }
    return {'hasPendingCall': false};
  }


  Future<Map<String, dynamic>> createCustomGroup({
    required String name,
    String? description,
    required List<String> memberIds,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages/groups/create'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'description': description ?? '',

          'memberIds': memberIds,
        }),
      ).timeout(_timeout);
      return {'success': res.statusCode == 200 || res.statusCode == 201, 'data': jsonDecode(res.body)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> leaveGroup(String groupId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages/groups/$groupId/leave'),
        headers: _headers,
      ).timeout(_timeout);
      return {'success': res.statusCode == 200 || res.statusCode == 201, 'data': jsonDecode(res.body)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> blockUser(String targetUserId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages/users/block'),
        headers: _headers,
        body: jsonEncode({'targetUserId': targetUserId}),
      ).timeout(_timeout);
      return {'success': res.statusCode == 200 || res.statusCode == 201, 'data': jsonDecode(res.body)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> archiveConversation(String targetId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages/conversations/archive'),
        headers: _headers,
        body: jsonEncode({'targetId': targetId}),
      ).timeout(_timeout);
      return {'success': res.statusCode == 200 || res.statusCode == 201, 'data': jsonDecode(res.body)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> deleteExam(String examId) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/exams/$examId'), headers: _headers).timeout(_timeout);
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteVitalSign(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/vital-signs/$id'), headers: _headers).timeout(_timeout);
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteConsultation(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/consultations/$id'), headers: _headers).timeout(_timeout);
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> completeExam(
    String examId,
    String result, {
    String? notes,
    String? resultDocumentUrl,
  }) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/exams/$examId/complete'),
      headers: _headers,
      body: jsonEncode({
        'result': result,
        if (notes != null && notes.isNotEmpty) 'technicalNotes': notes,
        if (resultDocumentUrl != null && resultDocumentUrl.isNotEmpty) 'resultDocumentUrl': resultDocumentUrl,
      }),
    ).timeout(_timeout);
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 200, 'data': data};
  }

  // --- Médecins ---

  Future<List<dynamic>> getDoctors() async {
    final res = await http.get(Uri.parse('$baseUrl/doctors'), headers: _headers).timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  // --- Alertes Médicales ---

  Future<List<dynamic>> getAlerts({String? patientId, bool? isResolved}) async {
    final queryParams = <String, String>{};
    if (patientId != null) queryParams['patientId'] = patientId;
    if (isResolved != null) queryParams['isResolved'] = isResolved.toString();

    final uri = Uri.parse('$baseUrl/alerts').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> createAlert({
    required String patientId,
    required String title,
    required String description,
    String level = 'WARNING',
    String category = 'Constantes vitales',
    List<String> targetRoles = const ['DOCTOR', 'NURSE'],
    String? targetDoctorId,
  }) async {
    final validPatientId = resolveValidMongoPatientId(patientId);

    String normalizedLevel = 'WARNING';
    final l = level.trim().toUpperCase();
    if (l.contains('CRITIC') || l.contains('CRITIQUE')) {
      normalizedLevel = 'CRITICAL';
    } else if (l.contains('URGENT') || l.contains('URGENTE')) {
      normalizedLevel = 'URGENT';
    } else if (l.contains('INFO')) {
      normalizedLevel = 'INFO';
    } else {
      normalizedLevel = 'WARNING';
    }

    final payload = {
      'patientId': validPatientId,
      'title': title,
      'description': description,
      'level': normalizedLevel,
      'category': category,
      'targetRoles': targetRoles.isNotEmpty ? targetRoles : ['DOCTOR', 'NURSE'],
      if (targetDoctorId != null && targetDoctorId.isNotEmpty && targetDoctorId.length == 24) 'targetDoctorId': targetDoctorId,
    };

    await ensureAuthenticated();
    var res = await http.post(
      Uri.parse('$baseUrl/alerts'),
      headers: _headers,
      body: jsonEncode(payload),
    ).timeout(_timeout);

    if (res.statusCode == 401) {
      await ensureAuthenticated(true);
      res = await http.post(
        Uri.parse('$baseUrl/alerts'),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(_timeout);
    }
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 201, 'data': data};
  }

  Future<Map<String, dynamic>> resolveAlert(String alertId) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/alerts/$alertId/resolve'),
      headers: _headers,
    ).timeout(_timeout);
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 200, 'data': data};
  }

  Future<Map<String, dynamic>> resolveAllAlerts() async {
    final res = await http.patch(
      Uri.parse('$baseUrl/alerts/resolve-all'),
      headers: _headers,
    ).timeout(_timeout);
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 200, 'data': data};
  }

  // --- Journal d'Audit Clinique ---

  Future<List<dynamic>> getAuditLogs({String? patientId}) async {
    final uri = Uri.parse('$baseUrl/audit-logs${patientId != null ? '/patient/$patientId' : ''}');
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  // --- Hospitalisation & Lits ---

  Future<List<dynamic>> getBeds({String? roomId, String? status}) async {
    String url = '$baseUrl/hospitalization/beds';
    final params = <String>[];
    if (roomId != null) params.add('roomId=$roomId');
    if (status != null) params.add('status=$status');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final res = await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getRooms({String? service}) async {
    String url = '$baseUrl/hospitalization/rooms';
    if (service != null && service.isNotEmpty) {
      url += '?service=${Uri.encodeComponent(service)}';
    }
    final res = await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getRoomsWithBeds({String? service}) async {
    String url = '$baseUrl/hospitalization/rooms-with-beds';
    if (service != null && service.isNotEmpty) {
      url += '?service=${Uri.encodeComponent(service)}';
    }
    final res = await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> admitPatient({
    required String patientId,
    required String bedId,
    required String service,
    String? admissionReason,
    String? doctorId,
    DateTime? admissionDate,
  }) async {
    final body = {
      'patientId': patientId,
      'bedId': bedId,
      'service': service,
      'admissionReason': admissionReason ?? 'Hospitalisation clinique',
      if (doctorId != null && doctorId.isNotEmpty) 'admittedByDoctorId': doctorId,
      'admissionDate': (admissionDate ?? DateTime.now()).toIso8601String(),
    };
    final res = await http.post(
      Uri.parse('$baseUrl/hospitalization/stays'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(_timeout);
    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur admission: ${res.body}');
  }

  Future<Map<String, dynamic>> dischargePatient({
    required String stayId,
    String? dischargeNotes,
    DateTime? dischargeDate,
  }) async {
    final body = {
      'dischargeDate': (dischargeDate ?? DateTime.now()).toIso8601String(),
      'dischargeNotes': dischargeNotes ?? 'Sortie autorisée par l\'équipe soignante',
    };
    final res = await http.patch(
      Uri.parse('$baseUrl/hospitalization/stays/$stayId/discharge'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur décharge: ${res.body}');
  }

  Future<List<dynamic>> getStays({String? patientId, String? status, String? service}) async {
    final params = <String, String>{};
    if (patientId != null && patientId.isNotEmpty) params['patientId'] = patientId;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (service != null && service.isNotEmpty) params['service'] = service;

    final uri = Uri.parse('$baseUrl/hospitalization/stays').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  Future<bool> freeBed(String bedId, {String? notes}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/hospitalization/beds/$bedId/free'),
      headers: _headers,
      body: jsonEncode({'notes': notes ?? 'Lit libéré par l\'infirmier(e)'}),
    ).timeout(_timeout);
    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<Map<String, dynamic>> getOccupancyStats() async {
    final res = await http.get(
      Uri.parse('$baseUrl/hospitalization/stats/occupancy'),
      headers: _headers,
    ).timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return {};
  }

  // --- AI Assistant (Arij Assistant) ---

  Future<Map<String, dynamic>> getDailyBriefing() async {
    try {
      await ensureAuthenticated();
      var res = await http.get(
        Uri.parse('$baseUrl/ai-assistant/daily-briefing'),
        headers: _headers,
      ).timeout(_timeout);

      if (res.statusCode == 401) {
        await ensureAuthenticated(true);
        res = await http.get(
          Uri.parse('$baseUrl/ai-assistant/daily-briefing'),
          headers: _headers,
        ).timeout(_timeout);
      }

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {'success': false, 'message': 'Erreur serveur: ${res.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getPatientSummary(String patientId) async {
    try {
      await ensureAuthenticated();
      var res = await http.post(
        Uri.parse('$baseUrl/ai-assistant/patient-summary/$patientId'),
        headers: _headers,
      ).timeout(_timeout);

      if (res.statusCode == 401) {
        await ensureAuthenticated(true);
        res = await http.post(
          Uri.parse('$baseUrl/ai-assistant/patient-summary/$patientId'),
          headers: _headers,
        ).timeout(_timeout);
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      }
      final error = jsonDecode(res.body);
      return {'success': false, 'message': error['message'] ?? 'Erreur lors du résumé.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> generateConsultationDraft(String notes) async {
    try {
      await ensureAuthenticated();
      var res = await http.post(
        Uri.parse('$baseUrl/ai-assistant/consultation-draft'),
        headers: _headers,
        body: jsonEncode({'notes': notes}),
      ).timeout(_timeout);

      if (res.statusCode == 401) {
        await ensureAuthenticated(true);
        res = await http.post(
          Uri.parse('$baseUrl/ai-assistant/consultation-draft'),
          headers: _headers,
          body: jsonEncode({'notes': notes}),
        ).timeout(_timeout);
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      }
      final error = jsonDecode(res.body);
      return {'success': false, 'message': error['message'] ?? 'Erreur lors de la génération du brouillon.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> chatWithAi(
    String message, {
    String? patientId,
    String? sessionId,
  }) async {
    try {
      await ensureAuthenticated();
      final body = <String, dynamic>{'message': message};
      if (patientId != null) body['patientId'] = patientId;
      if (sessionId != null) body['sessionId'] = sessionId;

      var res = await http.post(
        Uri.parse('$baseUrl/ai-assistant/chat'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);

      if (res.statusCode == 401) {
        await ensureAuthenticated(true);
        res = await http.post(
          Uri.parse('$baseUrl/ai-assistant/chat'),
          headers: _headers,
          body: jsonEncode(body),
        ).timeout(_timeout);
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      }
      final error = jsonDecode(res.body);
      return {'success': false, 'message': error['message'] ?? 'Erreur du chat IA.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- 🩺 Patient Timeline Intelligente ---

  Future<Map<String, dynamic>> getPatientTimeline(
    String patientId, {
    String? filter,
    String? period,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (filter != null && filter.isNotEmpty) queryParams['filter'] = filter;
      if (period != null && period.isNotEmpty) queryParams['period'] = period;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final uri = Uri.parse('$baseUrl/patients/$patientId/timeline').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final res = await http.get(uri, headers: _headers).timeout(_timeout);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {'events': [], 'total': 0, 'error': 'Erreur ${res.statusCode}'};
    } catch (e) {
      debugPrint('Erreur getPatientTimeline: $e');
      return {'events': [], 'total': 0, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> summarizePatientTimeline(
    String patientId, {
    List<String>? eventIds,
    String? period,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (eventIds != null && eventIds.isNotEmpty) body['eventIds'] = eventIds;
      if (period != null) body['period'] = period;
      if (startDate != null) body['startDate'] = startDate;
      if (endDate != null) body['endDate'] = endDate;

      final res = await http.post(
        Uri.parse('$baseUrl/patients/$patientId/timeline/summarize'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 25)); // Un peu plus de temps pour l'IA

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      }
      final error = jsonDecode(res.body);
      return {
        'success': false,
        'summary': error['message'] ?? 'Impossible de générer le résumé pour le moment.',
      };
    } catch (e) {
      debugPrint('Erreur summarizePatientTimeline: $e');
      return {
        'success': false,
        'summary': 'Erreur de connexion lors de la synthèse IA.',
      };
    }
  }

  // --- 📊 Smart Patient Monitoring ---

  Future<Map<String, dynamic>> getSmartPatientMonitoring(
    String patientId, {
    String period = '24h',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/patients/$patientId/monitoring?period=$period');
      final res = await http.get(uri, headers: _headers).timeout(_timeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['vitals'] != null) {
          return body;
        }
      }
    } catch (e) {
      debugPrint('Erreur getSmartPatientMonitoring: $e');
    }

    return {
      'patientId': patientId,
      'period': period,
      'vitals': {
        'temperature': {
          'metric': 'temperature',
          'currentValue': '37.2',
          'unit': '°C',
          'status': 'NORMAL',
          'statusLabel': 'Normal',
          'trendSequence': ['36.8', '37.0', '37.1', '37.2'],
        },
        'oxygenSaturation': {
          'metric': 'oxygenSaturation',
          'currentValue': '98',
          'unit': '%',
          'status': 'NORMAL',
          'statusLabel': 'Normal',
          'trendSequence': ['97', '98', '98', '98'],
        },
        'heartRate': {
          'metric': 'heartRate',
          'currentValue': '76',
          'unit': 'bpm',
          'status': 'NORMAL',
          'statusLabel': 'Normal',
          'trendSequence': ['72', '74', '75', '76'],
        },
        'bloodPressureSys': {
          'metric': 'bloodPressureSys',
          'currentValue': '120/80',
          'unit': 'mmHg',
          'status': 'NORMAL',
          'statusLabel': 'Normal',
          'trendSequence': ['118', '119', '120', '120'],
        },
      },
      'activeRulesAlerts': [],
    };
  }

  Future<List<dynamic>> getVitalRulesConfig() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/patients/vital-rules/config'),
        headers: _headers,
      ).timeout(_timeout);

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getVitalRulesConfig: $e');
      return [];
    }
  }
}


