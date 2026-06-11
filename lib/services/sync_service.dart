import 'local_symptom_repository.dart';
import 'supabase_backend_service.dart';

class SyncService {
  SyncService({
    required this.local,
    required this.remote,
  });

  final LocalSymptomRepository local;
  final SupabaseBackendService remote;
  bool _isSyncing = false;

  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _pushPending();
      await _pullRemote();
      await local.setLastSyncedAt(DateTime.now().toUtc().toIso8601String());
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushPending() async {
    final entries = await local.getPending('entries');
    for (final entry in entries) {
      final saved = await remote.upsertEntry(entry);
      await local.markSynced(
          'entries', entry['id'] as int, saved['id'] as String);
    }

    final medications = await local.getPending('medications');
    for (final medication in medications) {
      final saved = await remote.upsertMedication(medication);
      await local.markSynced(
        'medications',
        medication['id'] as int,
        saved['id'] as String,
      );
    }

    final appointments = await local.getPending('appointments');
    for (final appointment in appointments) {
      final saved = await remote.upsertAppointment(appointment);
      await local.markSynced(
        'appointments',
        appointment['id'] as int,
        saved['id'] as String,
      );
    }
  }

  Future<void> _pullRemote() async {
    final since = await local.getLastSyncedAt();

    final entries = await remote.fetchEntriesSince(since);
    for (final entry in entries) {
      await local.upsertRemoteEntry(entry);
    }

    final medications = await remote.fetchMedicationsSince(since);
    for (final medication in medications) {
      await local.upsertRemoteMedication(medication);
    }

    final appointments = await remote.fetchAppointmentsSince(since);
    for (final appointment in appointments) {
      await local.upsertRemoteAppointment(appointment);
    }
  }
}
