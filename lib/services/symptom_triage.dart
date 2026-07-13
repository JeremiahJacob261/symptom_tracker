import '../data/symptom_taxonomy.dart';

/// A deliberately conservative, deterministic pre-screen.
///
/// This does not diagnose conditions or replace emergency services. It exists
/// so that a generative model can never suppress a clearly urgent prompt.
class SymptomTriage {
  static const _urgentTerms = [
    'chest pain',
    'chest discomfort',
    'shortness of breath',
    'difficulty breathing',
    'trouble breathing',
    'severe bleeding',
    'faint',
    'loss of consciousness',
    'confusion',
    'numbness',
    'weakness',
    'one-sided weakness',
    'face drooping',
    'worst headache',
    'seizure',
    'suicidal',
    'self harm',
  ];

  static TriageResult evaluate(Map<String, dynamic> entry) {
    final flags = <String>{};
    final pain = _readPainLevel(entry);
    final temperature = readTemperatureCelsius(entry);
    final text = [
      entry['body_area'],
      entry['notes'],
      ...readEntrySymptoms(entry),
      readCustomSymptoms(entry),
    ].whereType<Object>().join(' ').toLowerCase();

    if (pain != null && pain >= 9) {
      flags.add('Very high pain was recorded.');
    }
    if (temperature != null && temperature >= 39.4) {
      flags.add('Very high fever was recorded.');
    }
    for (final term in _urgentTerms) {
      if (text.contains(term)) {
        flags.add('Urgent symptom language was recorded: "$term".');
      }
    }

    return TriageResult(flags.toList());
  }

  static int? _readPainLevel(Map<String, dynamic> entry) {
    final value = entry['pain_level'] ?? entry['painLevel'];
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }
}

class TriageResult {
  const TriageResult(this.flags);

  final List<String> flags;
  bool get needsUrgentCarePrompt => flags.isNotEmpty;
}
