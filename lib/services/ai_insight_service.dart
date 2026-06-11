import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_backend.dart';
import 'health_analytics.dart';

class AiInsightService {
  static const workerUrl = "https://symptom-tracker-ai.jeremiahjacob261.workers.dev";
  //flutter build web   --dart-define=SUPABASE_URL=https://pggvcuchcrytifxnzhef.supabase.co/rest/v1/   --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_HIltu5fP_Y4YU-mhgABncg_wlmIu5jx   --dart-define=CLOUDFLARE_AI_WORKER_URL=https://symptom-tracker-ai.jeremiahjacob261.workers.dev
  static bool get hasWorkerConfig => workerUrl.trim().isNotEmpty;

  static Future<InsightPayload> generate({
    required List<Map<String, dynamic>> entries,
    String range = '7d',
    String type = 'insights',
    String? entryId,
  }) async {
    if (!hasWorkerConfig || !AppBackend.isRemoteEnabled) {
      return HealthAnalytics.fallbackInsight(entries);
    }

    final token = AppBackend.remote?.accessToken;
    if (token == null || token.isEmpty) {
      return HealthAnalytics.fallbackInsight(entries);
    }

    try {
      final uri = Uri.parse(workerUrl).replace(path: _joinPath('/ai/$type'));
      final response = await http.post(
        uri,
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'range': range,
          'type': type,
          if (entryId != null) 'entryId': entryId,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return HealthAnalytics.fallbackInsight(entries);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return InsightPayload.fromJson(decoded);
    } catch (_) {
      return HealthAnalytics.fallbackInsight(entries);
    }
  }

  static String _joinPath(String path) {
    final base = Uri.parse(workerUrl);
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return '$prefix$path';
  }
}
