import 'package:flutter_test/flutter_test.dart';
import 'package:symptom_tracker/services/health_analytics.dart';

void main() {
  test('weeklyStats compares this week and last week', () {
    final now = DateTime(2026, 6, 10, 12);
    final stats = HealthAnalytics.weeklyStats(
      [
        {
          'timestamp': DateTime(2026, 6, 9).toIso8601String(),
          'pain_level': 4,
          'mood': 'Calm',
        },
        {
          'timestamp': DateTime(2026, 6, 10).toIso8601String(),
          'pain_level': 6,
          'mood': 'Calm',
        },
        {
          'timestamp': DateTime(2026, 6, 3).toIso8601String(),
          'pain_level': 8,
          'mood': 'Stressed',
        },
      ],
      now: now,
    );

    expect(stats.averagePainThisWeek, 5);
    expect(stats.averagePainLastWeek, 8);
    expect(stats.mostCommonMoodThisWeek, 'Calm');
    expect(stats.daysLoggedThisWeek, 2);
    expect(stats.trend, 'better');
  });

  test('weeklyStats handles empty data', () {
    final stats = HealthAnalytics.weeklyStats(
      const [],
      now: DateTime(2026, 6, 10),
    );

    expect(stats.averagePainThisWeek, isNull);
    expect(stats.averagePainLastWeek, isNull);
    expect(stats.mostCommonMoodThisWeek, isNull);
    expect(stats.daysLoggedThisWeek, 0);
    expect(stats.trend, 'unknown');
  });

  test('fallbackInsight includes safety disclaimer', () {
    final insight = HealthAnalytics.fallbackInsight([
      {
        'timestamp': DateTime(2026, 6, 10).toIso8601String(),
        'pain_level': 9,
        'body_area': 'Chest',
        'mood': 'Anxious',
        'notes': 'shortness of breath',
      },
    ]);

    expect(insight.safetyStatus, 'urgent');
    expect(insight.redFlags, isNotEmpty);
    expect(
      insight.careGuidance.join(' '),
      contains('This is not a diagnosis'),
    );
  });

  test('symptomFrequency reads structured and custom symptoms', () {
    final entries = [
      {
        'timestamp': DateTime(2026, 6, 10).toIso8601String(),
        'pain_level': 4,
        'body_area': 'Head',
        'mood': 'Calm',
        'symptoms_json': '["Fever","Headache"]',
        'custom_symptoms': 'Light sensitivity',
      },
      {
        'timestamp': DateTime(2026, 6, 11).toIso8601String(),
        'pain_level': 6,
        'body_area': 'Chest',
        'mood': 'Anxious',
        'symptoms_json': '["Fever","Shortness of breath"]',
        'temperature_celsius': 39.5,
      },
    ];

    final frequency = HealthAnalytics.symptomFrequency(entries);
    final insight = HealthAnalytics.fallbackInsight(entries);

    expect(frequency['Fever'], 2);
    expect(frequency['Headache'], 1);
    expect(frequency['Light sensitivity'], 1);
    expect(insight.patterns.join(' '), contains('Most common symptom: Fever'));
    expect(insight.redFlags.join(' '), contains('Very high fever'));
  });
}
