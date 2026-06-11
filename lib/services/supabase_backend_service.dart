import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBackendService {
  SupabaseBackendService._(this.client);

  static const supabaseUrl = "https://pggvcuchcrytifxnzhef.supabase.co/rest/v1";
  static const publishableKey ="sb_publishable_HIltu5fP_Y4YU-mhgABncg_wlmIu5jx";
  static const photoBucket = 'mar_symptom_photos';

  final SupabaseClient client;

  static bool get hasConfig =>
      supabaseUrl.trim().isNotEmpty && publishableKey.trim().isNotEmpty;

  static Future<SupabaseBackendService?> bootstrap() async {
    if (!hasConfig) return null;

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: publishableKey,
    );

    final service = SupabaseBackendService._(Supabase.instance.client);
    await service.ensureAnonymousSession();
    await service.ensureProfile();
    return service;
  }

  String get userId {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Supabase user is not signed in.');
    }
    return user.id;
  }

  String? get accessToken => client.auth.currentSession?.accessToken;

  Future<void> ensureAnonymousSession() async {
    if (client.auth.currentSession != null) return;
    await client.auth.signInAnonymously();
  }

  Future<void> ensureProfile({String? displayName}) async {
    final prefs = await SharedPreferences.getInstance();
    final name = displayName ?? prefs.getString('userName');
    await client.from('mar_profiles').upsert({
      'id': userId,
      'display_name': name,
      'timezone': DateTime.now().timeZoneName,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> upsertEntry(Map<String, dynamic> local) async {
    final photoPath = await _uploadPhotoIfNeeded(local);
    final response = await client
        .from('mar_symptom_entries')
        .upsert(
          {
            'user_id': userId,
            'client_id': local['client_id'],
            'pain_level': local['pain_level'],
            'body_area': local['body_area'],
            'mood': local['mood'],
            'notes': local['notes'],
            'photo_path': photoPath,
            'occurred_at': local['timestamp'],
            'updated_at': local['updated_at'],
            'deleted_at': local['deleted_at'],
          },
          onConflict: 'user_id,client_id',
        )
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> upsertMedication(
    Map<String, dynamic> local,
  ) async {
    final response = await client
        .from('mar_medications')
        .upsert(
          {
            'user_id': userId,
            'client_id': local['client_id'],
            'name': local['name'],
            'dosage': local['dosage'],
            'frequency': local['frequency'],
            'is_active': local['is_active'] == 1,
            'updated_at': local['updated_at'],
            'deleted_at': local['deleted_at'],
          },
          onConflict: 'user_id,client_id',
        )
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> upsertAppointment(
    Map<String, dynamic> local,
  ) async {
    final response = await client
        .from('mar_appointments')
        .upsert(
          {
            'user_id': userId,
            'client_id': local['client_id'],
            'title': local['title'],
            'doctor': local['doctor'],
            'appointment_date': local['date'],
            'appointment_time': _normalizeTime(local['time']),
            'notes': local['notes'],
            'updated_at': local['updated_at'],
            'deleted_at': local['deleted_at'],
          },
          onConflict: 'user_id,client_id',
        )
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchEntriesSince(String? since) async {
    var query = client.from('mar_symptom_entries').select();
    if (since != null) query = query.gt('updated_at', since);
    final rows = await query.order('updated_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMedicationsSince(
      String? since) async {
    var query = client.from('mar_medications').select();
    if (since != null) query = query.gt('updated_at', since);
    final rows = await query.order('updated_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAppointmentsSince(
      String? since) async {
    var query = client.from('mar_appointments').select();
    if (since != null) query = query.gt('updated_at', since);
    final rows = await query.order('updated_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>?> fetchLatestAiInsight({
    String type = 'insights',
    String range = '7d',
  }) async {
    final rows = await client
        .from('mar_ai_insights')
        .select()
        .eq('insight_type', type)
        .eq('range_key', range)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> fetchLatestAiReport({
    String reportType = 'weekly_summary',
    String range = '7d',
  }) async {
    final rows = await client
        .from('mar_ai_reports')
        .select()
        .eq('report_type', reportType)
        .eq('range_key', range)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> saveAiFeedback({
    String? insightId,
    String? reportId,
    required String rating,
    String? notes,
  }) async {
    await client.from('mar_ai_feedback').insert({
      'user_id': userId,
      'insight_id': insightId,
      'report_id': reportId,
      'rating': rating,
      'notes': notes,
    });
  }

  Future<String?> _uploadPhotoIfNeeded(Map<String, dynamic> local) async {
    final path = local['photo_path']?.toString();
    if (path == null || path.isEmpty || path.startsWith('$userId/')) {
      return path;
    }

    final clientId = local['client_id']?.toString() ?? 'unassigned';
    final encodedBytes = local['photo_bytes_base64']?.toString();
    if (encodedBytes != null && encodedBytes.isNotEmpty) {
      final objectPath = '$userId/$clientId/photo.jpg';
      await client.storage.from(photoBucket).uploadBinary(
            objectPath,
            Uint8List.fromList(base64Decode(encodedBytes)),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return objectPath;
    }

    if (kIsWeb) {
      return path;
    }

    final file = File(path);
    if (!await file.exists()) return path;

    final objectPath = '$userId/$clientId/${file.uri.pathSegments.last}';
    await client.storage.from(photoBucket).upload(
          objectPath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return objectPath;
  }

  String? _normalizeTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    if (RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(raw)) return raw;
    try {
      return DateFormat.Hms().format(DateFormat.jm().parse(raw));
    } catch (_) {
      return null;
    }
  }
}
