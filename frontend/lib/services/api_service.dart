import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

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
    );

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
      final res = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: _headers,
      );
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
    );

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
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (department != null && department.isNotEmpty && department != 'ALL') queryParams['department'] = department;
    if (attendingDoctorId != null && attendingDoctorId.isNotEmpty) queryParams['attendingDoctorId'] = attendingDoctorId;
    if (assignedMidwifeId != null && assignedMidwifeId.isNotEmpty) queryParams['assignedMidwifeId'] = assignedMidwifeId;
    if (assignedNurseId != null && assignedNurseId.isNotEmpty) queryParams['assignedNurseId'] = assignedNurseId;

    final uri = Uri.parse('$baseUrl/patients').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
      final uniqueMap = <String, dynamic>{};
      for (final item in list) {
        if (item is Map && item['_id'] != null) {
          uniqueMap[item['_id'].toString()] = item;
        }
      }
      return uniqueMap.values.toList();
    }
    return [];
  }

  Future<List<dynamic>> getNurses() async {
    final res = await http.get(Uri.parse('$baseUrl/users?role=NURSE'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getMidwives() async {
    final res = await http.get(Uri.parse('$baseUrl/users?role=MIDWIFE'), headers: _headers);
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

    final uri = Uri.parse('$baseUrl/consultations').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
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
    final payload = {
      'patientId': patientId,
      'doctorId': doctorId,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'motive': motive,
      'diagnostic': diagnostic,
      if (symptoms != null && symptoms.isNotEmpty) 'symptoms': symptoms,
      if (clinicalExam != null && clinicalExam.isNotEmpty) 'clinicalExam': clinicalExam,
      if (prescription != null && prescription.isNotEmpty) 'prescription': prescription,
      if (prescriptionItems != null && prescriptionItems.isNotEmpty) 'prescriptionItems': prescriptionItems,
      if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
      if (observations != null && observations.isNotEmpty) 'observations': observations,
      if (followUpDate != null && followUpDate.isNotEmpty) 'followUpDate': followUpDate,
    };

    final res = await http.post(
      Uri.parse('$baseUrl/consultations'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 201, 'data': data};
  }

  // --- Constantes Vitales ---

  Future<List<dynamic>> getVitalSigns({String? patientId}) async {
    final uri = Uri.parse('$baseUrl/vital-signs${patientId != null ? '?patientId=$patientId' : ''}');
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
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
    String? notes,
  }) async {
    final effectiveUserId = (recordedByUserId != null && recordedByUserId.isNotEmpty)
        ? recordedByUserId
        : (currentUser?['id'] ?? currentUser?['_id'] ?? '');

    final payload = {
      'patientId': patientId,
      if (effectiveUserId.isNotEmpty) 'recordedByUserId': effectiveUserId,
      'recordedAt': DateTime.now().toIso8601String(),
      if (temperature != null) 'temperature': temperature,
      if (bloodPressureSystolic != null) 'bloodPressureSystolic': bloodPressureSystolic,
      if (bloodPressureDiastolic != null) 'bloodPressureDiastolic': bloodPressureDiastolic,
      if (heartRate != null) 'heartRate': heartRate,
      if (oxygenSaturation != null) 'oxygenSaturation': oxygenSaturation,
      if (respiratoryRate != null) 'respiratoryRate': respiratoryRate,
      if (weight != null) 'weight': weight,
      if (notes != null) 'notes': notes,
    };

    final res = await http.post(
      Uri.parse('$baseUrl/vital-signs'),
      headers: _headers,
      body: jsonEncode(payload),
    );
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
    await ensureAuthenticated();
    final queryParams = <String, String>{};

    if (status != null && status != 'ALL') queryParams['status'] = status;
    if (patientId != null) queryParams['patientId'] = patientId;
    if (service != null && service.isNotEmpty && service != 'ALL') queryParams['service'] = service;
    if (doctorId != null) queryParams['doctorId'] = doctorId;
    if (technicianId != null) queryParams['technicianId'] = technicianId;
    if (priority != null) queryParams['priority'] = priority;

    final uri = Uri.parse('$baseUrl/exams').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getTechnicians() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/technicians'), headers: _headers);
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

    final cleanPatId = patientId.trim();
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
      final res = await http.post(
        Uri.parse('$baseUrl/exams'),
        headers: _headers,
        body: jsonEncode(payload),
      );
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
    );
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 200, 'data': data};
  }

  Future<void> ensureAuthenticated() async {
    if (token != null) return;
    final restored = await tryAutoLogin();
    if (!restored || token == null) {
      await login('dr.karima@arij.tn', 'Doctor123!').catchError((_) => <String, dynamic>{});
    }
  }

  // --- Messagerie Staff & Téléphonie ---

  Future<List<dynamic>> getStaffUsers() async {
    await ensureAuthenticated();
    try {
      final res = await http.get(Uri.parse('$baseUrl/users'), headers: _headers);
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
      final res = await http.get(Uri.parse('$baseUrl/messages/conversations'), headers: _headers);
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
      final res = await http.get(uri, headers: _headers);
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
      );
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
      );
      final data = jsonDecode(res.body);
      return {'success': res.statusCode == 201 || res.statusCode == 200, 'data': data};
    } catch (e) {
      debugPrint('Erreur sendCallSignal: $e');
      return {'success': false, 'error': e.toString()};
    }
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
      );
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
      );
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
      );
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
      );
      return {'success': res.statusCode == 200 || res.statusCode == 201, 'data': jsonDecode(res.body)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> deleteExam(String examId) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/exams/$examId'), headers: _headers);
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteVitalSign(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/vital-signs/$id'), headers: _headers);
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteConsultation(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/consultations/$id'), headers: _headers);
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
    );
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 200, 'data': data};
  }

  // --- Médecins ---

  Future<List<dynamic>> getDoctors() async {
    final res = await http.get(Uri.parse('$baseUrl/doctors'), headers: _headers);
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
    final res = await http.get(uri, headers: _headers);
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
    List<String> targetRoles = const ['DOCTOR'],
    String? targetDoctorId,
  }) async {
    final payload = {
      'patientId': patientId,
      'title': title,
      'description': description,
      'level': level,
      'category': category,
      'targetRoles': targetRoles,
      if (targetDoctorId != null && targetDoctorId.isNotEmpty) 'targetDoctorId': targetDoctorId,
    };

    final res = await http.post(
      Uri.parse('$baseUrl/alerts'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 201, 'data': data};
  }

  Future<Map<String, dynamic>> resolveAlert(String alertId) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/alerts/$alertId/resolve'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 200, 'data': data};
  }

  Future<Map<String, dynamic>> resolveAllAlerts() async {
    final res = await http.patch(
      Uri.parse('$baseUrl/alerts/resolve-all'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    return {'success': res.statusCode == 200, 'data': data};
  }

  // --- Journal d'Audit Clinique ---

  Future<List<dynamic>> getAuditLogs({String? patientId}) async {
    final uri = Uri.parse('$baseUrl/audit-logs${patientId != null ? '/patient/$patientId' : ''}');
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  // --- Hospitalisation & Lits ---

  Future<List<dynamic>> getBeds() async {
    final res = await http.get(Uri.parse('$baseUrl/hospitalization/beds'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getRooms() async {
    final res = await http.get(Uri.parse('$baseUrl/hospitalization/rooms'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  // --- AI Assistant (Arij Assistant) ---

  Future<Map<String, dynamic>> getDailyBriefing() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/ai-assistant/daily-briefing'),
        headers: _headers,
      );
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
      final res = await http.post(
        Uri.parse('$baseUrl/ai-assistant/patient-summary/$patientId'),
        headers: _headers,
      );
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
      final res = await http.post(
        Uri.parse('$baseUrl/ai-assistant/consultation-draft'),
        headers: _headers,
        body: jsonEncode({'notes': notes}),
      );
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
      final body = <String, dynamic>{'message': message};
      if (patientId != null) body['patientId'] = patientId;
      if (sessionId != null) body['sessionId'] = sessionId;

      final res = await http.post(
        Uri.parse('$baseUrl/ai-assistant/chat'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      }
      final error = jsonDecode(res.body);
      return {'success': false, 'message': error['message'] ?? 'Erreur du chat IA.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

