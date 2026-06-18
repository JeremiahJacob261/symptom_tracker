import 'package:intl/intl.dart';

import '../data/symptom_taxonomy.dart';

class WeeklyStats {
  const WeeklyStats({
    required this.averagePainThisWeek,
    required this.averagePainLastWeek,
    required this.mostCommonMoodThisWeek,
    required this.daysLoggedThisWeek,
    required this.trend,
  });

  final double? averagePainThisWeek;
  final double? averagePainLastWeek;
  final String? mostCommonMoodThisWeek;
  final int daysLoggedThisWeek;
  final String trend;
}

class InsightPayload {
  const InsightPayload({
    required this.summary,
    required this.patterns,
    required this.education,
    required this.careGuidance,
    required this.redFlags,
    required this.trend,
    required this.safetyStatus,
    required this.model,
  });

  final String summary;
  final List<String> patterns;
  final List<String> education;
  final List<String> careGuidance;
  final List<String> redFlags;
  final String trend;
  final String safetyStatus;
  final String model;

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'patterns': patterns,
      'education': education,
      'careGuidance': careGuidance,
      'redFlags': redFlags,
      'trend': trend,
      'safetyStatus': safetyStatus,
      'model': model,
    };
  }

  factory InsightPayload.fromJson(Map<String, dynamic> json) {
    List<String> readList(String key) {
      final value = json[key];
      if (value is List) return value.map((item) => item.toString()).toList();
      return const [];
    }

    return InsightPayload(
      summary: json['summary']?.toString() ?? 'No summary available yet.',
      patterns: readList('patterns'),
      education: readList('education'),
      careGuidance: readList('careGuidance'),
      redFlags: readList('redFlags'),
      trend: json['trend']?.toString() ?? 'unknown',
      safetyStatus: json['safetyStatus']?.toString() ?? 'safe',
      model: json['model']?.toString() ?? 'local-fallback',
    );
  }
}

class HealthAnalytics {
  static const disclaimer =
      'This is not a diagnosis. Consult a healthcare professional for medical advice.';

  static WeeklyStats weeklyStats(
    List<Map<String, dynamic>> entries, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final thisWeekStart = _startOfWeek(today);
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final nextWeekStart = thisWeekStart.add(const Duration(days: 7));

    final thisWeek = entries.where((entry) {
      final timestamp = parseEntryDate(entry);
      return timestamp != null &&
          !timestamp.isBefore(thisWeekStart) &&
          timestamp.isBefore(nextWeekStart);
    }).toList();

    final lastWeek = entries.where((entry) {
      final timestamp = parseEntryDate(entry);
      return timestamp != null &&
          !timestamp.isBefore(lastWeekStart) &&
          timestamp.isBefore(thisWeekStart);
    }).toList();

    final thisAverage = averagePain(thisWeek);
    final lastAverage = averagePain(lastWeek);

    return WeeklyStats(
      averagePainThisWeek: thisAverage,
      averagePainLastWeek: lastAverage,
      mostCommonMoodThisWeek: mostCommonValue(thisWeek, 'mood'),
      daysLoggedThisWeek: thisWeek
          .map((entry) {
            final timestamp = parseEntryDate(entry);
            return timestamp == null
                ? null
                : DateFormat('yyyy-MM-dd').format(timestamp);
          })
          .whereType<String>()
          .toSet()
          .length,
      trend: painTrend(thisAverage, lastAverage),
    );
  }

  static double? averagePain(List<Map<String, dynamic>> entries) {
    final levels = entries.map(readPainLevel).whereType<int>().toList();
    if (levels.isEmpty) return null;
    return levels.reduce((a, b) => a + b) / levels.length;
  }

  static int? readPainLevel(Map<String, dynamic> entry) {
    final value = entry['pain_level'] ?? entry['painLevel'];
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? mostCommonValue(
    List<Map<String, dynamic>> entries,
    String key,
  ) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final value = entry[key]?.toString();
      if (value == null || value.isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String painTrend(double? current, double? previous) {
    if (current == null || previous == null) return 'unknown';
    final delta = current - previous;
    if (delta.abs() < 0.5) return 'same';
    return delta < 0 ? 'better' : 'worse';
  }

  static DateTime? parseEntryDate(Map<String, dynamic> entry) {
    final value = entry['timestamp'] ?? entry['occurred_at'] ?? entry['date'];
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static Map<String, int> dayOfWeekFrequency(
      List<Map<String, dynamic>> entries) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final date = parseEntryDate(entry);
      if (date == null) continue;
      final key = DateFormat('EEEE').format(date);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  static Map<String, int> valueFrequency(
    List<Map<String, dynamic>> entries,
    String key,
  ) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final value = entry[key]?.toString();
      if (value == null || value.isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts;
  }

  static List<String> redFlags(List<Map<String, dynamic>> entries) {
    const urgentTerms = [
      'chest pain',
      'chest discomfort',
      'shortness of breath',
      'faint',
      'fainted',
      'numbness',
      'weakness',
      'confusion',
      'worst headache',
      'severe bleeding',
    ];

    final flags = <String>{};
    for (final entry in entries) {
      final pain = readPainLevel(entry);
      final notes = (entry['notes'] ?? '').toString().toLowerCase();
      final area = (entry['body_area'] ?? '').toString().toLowerCase();
      final symptoms = [
        ...readEntrySymptoms(entry),
        readCustomSymptoms(entry),
      ].join(' ').toLowerCase();
      final temperature = readTemperatureCelsius(entry);
      if (pain != null && pain >= 9) {
        flags.add('Very high pain was recorded.');
      }
      if (area.contains('chest') || symptoms.contains('chest')) {
        flags.add('Chest symptoms were recorded.');
      }
      if (temperature != null && temperature >= 39.4) {
        flags.add('Very high fever was recorded.');
      }
      for (final term in urgentTerms) {
        if (notes.contains(term) || symptoms.contains(term)) {
          flags.add('Urgent symptom language was found: "$term".');
        }
      }
    }
    return flags.toList();
  }

  static InsightPayload fallbackInsight(
    List<Map<String, dynamic>> entries, {
    DateTime? now,
  }) {
    if (entries.isEmpty) {
      return const InsightPayload(
        summary: 'Log a few symptoms to generate pattern insights.',
        patterns: [],
        education: [
          'Consistent daily logging helps reveal changes in symptom frequency and severity.',
        ],
        careGuidance: [
          disclaimer,
        ],
        redFlags: [],
        trend: 'unknown',
        safetyStatus: 'safe',
        model: 'local-fallback',
      );
    }

    final stats = weeklyStats(entries, now: now);
    final avg = averagePain(entries);
    final commonArea = mostCommonValue(entries, 'body_area');
    final commonMood = mostCommonValue(entries, 'mood');
    final symptomCounts = symptomFrequency(entries);
    final commonSymptom = symptomCounts.isEmpty
        ? null
        : symptomCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final flags = redFlags(entries);

    final patterns = <String>[
      if (avg != null) 'Average logged pain is ${avg.toStringAsFixed(1)}/10.',
      if (commonArea != null) 'Most common body area: $commonArea.',
      if (commonMood != null) 'Most common mood: $commonMood.',
      if (commonSymptom != null) 'Most common symptom: ${commonSymptom.key}.',
      if (stats.averagePainThisWeek != null)
        'This week average pain: ${stats.averagePainThisWeek!.toStringAsFixed(1)}/10.',
      if (stats.averagePainLastWeek != null)
        'Last week average pain: ${stats.averagePainLastWeek!.toStringAsFixed(1)}/10.',
    ];

    return InsightPayload(
      summary:
          'Based on ${entries.length} entries, your current trend is ${stats.trend}. Keep using this as a tracking aid and bring persistent changes to a clinician.',
      patterns: patterns,
      education: const [
        'Patterns are more reliable after several days of consistent entries.',
        'Mood, sleep, activity, and medication timing can influence how symptoms feel.',
      ],
      careGuidance: [
        if (flags.isNotEmpty)
          'Some entries contain possible red flags. Consider urgent medical advice if symptoms are severe, sudden, or worsening.',
        disclaimer,
      ],
      redFlags: flags,
      trend: stats.trend,
      safetyStatus: flags.isEmpty ? 'safe' : 'urgent',
      model: 'local-fallback',
    );
  }

  static Map<String, dynamic> statsForAi(List<Map<String, dynamic>> entries) {
    final weekly = weeklyStats(entries);
    return {
      'entryCount': entries.length,
      'averagePain': averagePain(entries),
      'averagePainThisWeek': weekly.averagePainThisWeek,
      'averagePainLastWeek': weekly.averagePainLastWeek,
      'daysLoggedThisWeek': weekly.daysLoggedThisWeek,
      'mostCommonMoodThisWeek': weekly.mostCommonMoodThisWeek,
      'trend': weekly.trend,
      'dayOfWeekFrequency': dayOfWeekFrequency(entries),
      'bodyAreaFrequency': valueFrequency(entries, 'body_area'),
      'moodFrequency': valueFrequency(entries, 'mood'),
      'symptomFrequency': symptomFrequency(entries),
      'temperatureReadingsCelsius':
          entries.map(readTemperatureCelsius).whereType<double>().toList(),
      'redFlags': redFlags(entries),
    };
  }

  static Map<String, int> symptomFrequency(List<Map<String, dynamic>> entries) {
    final counts = <String, int>{};
    for (final entry in entries) {
      for (final symptom in readEntrySymptoms(entry)) {
        counts[symptom] = (counts[symptom] ?? 0) + 1;
      }
      final custom = readCustomSymptoms(entry);
      if (custom.isNotEmpty) {
        counts[custom] = (counts[custom] ?? 0) + 1;
      }
    }
    return counts;
  }

  static DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }
}
