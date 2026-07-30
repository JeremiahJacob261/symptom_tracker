import 'package:flutter/foundation.dart';

import 'ai_insight_service.dart';
import 'health_analytics.dart';
import 'local_symptom_repository.dart';
import 'supabase_backend_service.dart';
import 'sync_service.dart';

class AppBackend {
  static final LocalSymptomRepository repository = LocalSymptomRepository();
  static SupabaseBackendService? remote;
  static SyncService? syncService;
  static Future<void>? _bootstrapFuture;
  static Future<InsightPayload?>? _preloadFuture;
  static Future<InsightPayload?> Function()? _preloadOverrideForTesting;
  static InsightPayload? preloadedAiInsight;
  static String preloadedAiInsightSource = 'Not loaded';
  static final ValueNotifier<String> preloadStatus =
      ValueNotifier<String>('Preparing your health insights...');

  static Future<void> bootstrap() async {
    final existing = _bootstrapFuture;
    if (existing != null) return existing;
    _bootstrapFuture = _bootstrap();
    return _bootstrapFuture!;
  }

  static Future<void> _bootstrap() async {
    await repository.init();
    try {
      remote = await SupabaseBackendService.bootstrap();
    } catch (error, stackTrace) {
      remote = null;
      syncService = null;
      if (kDebugMode) {
        debugPrint('Remote backend bootstrap failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }
    final backend = remote;
    if (backend == null) return;
    syncService = SyncService(local: repository, remote: backend);
    syncSoon();
  }

  static bool get isRemoteEnabled => remote != null;

  static void syncSoon() {
    final sync = syncService;
    if (sync == null) return;
    sync.sync().catchError((_) {});
  }

  static Future<void> updateProfileName(String name) async {
    final backend = remote;
    if (backend == null) return;
    await backend.ensureProfile(displayName: name);
  }

  static Future<Map<String, dynamic>?> latestAiInsight({
    String type = 'insights',
    String range = '7d',
  }) async {
    final backend = remote;
    if (backend == null) return null;
    try {
      return backend.fetchLatestAiInsight(type: type, range: range);
    } catch (_) {
      return null;
    }
  }

  static Future<InsightPayload?> preloadAiInsight({
    String type = 'insights',
    String range = '7d',
  }) {
    final override = _preloadOverrideForTesting;
    if (override != null) return override();
    final existing = _preloadFuture;
    if (existing != null) return existing;
    _preloadFuture = _preloadAiInsight(type: type, range: range);
    return _preloadFuture!;
  }

  static Future<InsightPayload?> _preloadAiInsight({
    required String type,
    required String range,
  }) async {
    try {
      preloadStatus.value = 'Preparing your health insights...';
      await bootstrap();

      preloadStatus.value = 'Syncing your records...';
      final sync = syncService;
      if (sync != null) {
        await sync.sync();
      }

      final entries = await repository.getEntries();
      if (entries.isEmpty) {
        preloadedAiInsight = null;
        preloadedAiInsightSource = 'No records';
        preloadStatus.value = 'No records to analyze yet.';
        return null;
      }

      preloadStatus.value = 'Running AI analysis...';
      final payload = await AiInsightService.generate(
        entries: entries,
        type: type,
        range: range,
        remoteEnabled: isRemoteEnabled,
        accessToken: remote?.accessToken,
      );

      if (payload.model == 'local-fallback') {
        preloadedAiInsight = null;
        preloadedAiInsightSource = 'Local fallback';
        preloadStatus.value = 'AI unavailable. Local analysis is ready.';
        return null;
      }

      preloadedAiInsight = payload;
      preloadedAiInsightSource = 'Cloudflare AI';
      preloadStatus.value = 'Finalizing...';
      return payload;
    } catch (error, stackTrace) {
      preloadedAiInsight = null;
      preloadedAiInsightSource = 'Local fallback';
      preloadStatus.value = 'AI unavailable. Local analysis is ready.';
      if (kDebugMode) {
        debugPrint('AI preload failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  @visibleForTesting
  static void setPreloadedAiInsightForTesting(InsightPayload? payload,
      {String source = 'Cloudflare AI'}) {
    preloadedAiInsight = payload;
    preloadedAiInsightSource = payload == null ? 'Not loaded' : source;
  }

  @visibleForTesting
  static void resetPreloadForTesting() {
    _preloadFuture = null;
    _preloadOverrideForTesting = null;
    preloadedAiInsight = null;
    preloadedAiInsightSource = 'Not loaded';
    preloadStatus.value = 'Preparing your health insights...';
  }

  @visibleForTesting
  static void setPreloadOverrideForTesting(
      Future<InsightPayload?> Function()? override) {
    _preloadOverrideForTesting = override;
  }
}
