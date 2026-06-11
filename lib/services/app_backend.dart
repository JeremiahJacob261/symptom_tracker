import 'local_symptom_repository.dart';
import 'supabase_backend_service.dart';
import 'sync_service.dart';

class AppBackend {
  static final LocalSymptomRepository repository = LocalSymptomRepository();
  static SupabaseBackendService? remote;
  static SyncService? syncService;

  static Future<void> bootstrap() async {
    await repository.init();
    remote = await SupabaseBackendService.bootstrap();
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
}
