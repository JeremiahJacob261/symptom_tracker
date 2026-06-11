import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:symptom_tracker/main.dart';
import 'package:symptom_tracker/services/app_backend.dart';
import 'package:symptom_tracker/services/local_symptom_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    LocalSymptomRepository.useWebStorageForTesting = true;
  });

  testWidgets('shows symptom tracker home screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('How are you feeling today?'), findsOneWidget);
    expect(find.text('Pain Level'), findsOneWidget);
    expect(find.text('Body Area'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
  });

  testWidgets('timeline detail opens from entry tap',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppBackend.repository.init();
    final uniqueNote =
        'timeline detail note ${DateTime.now().microsecondsSinceEpoch}';
    await DatabaseHelper.insertEntry({
      'pain_level': 7,
      'body_area': 'Head',
      'mood': 'Stressed',
      'notes': uniqueNote,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining(uniqueNote), findsOneWidget);
    await tester.tap(find.textContaining(uniqueNote));
    await tester.pumpAndSettle();

    expect(find.text('Pain level'), findsOneWidget);
    expect(find.text(uniqueNote), findsWidgets);
  });

  testWidgets('insights screen shows fallback AI sections', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppBackend.repository.init();
    await DatabaseHelper.insertEntry({
      'pain_level': 5,
      'body_area': 'Back',
      'mood': 'Neutral',
      'notes': 'fallback insight test',
      'timestamp': DateTime.now().toIso8601String(),
    });

    await tester.pumpWidget(const MaterialApp(home: InsightsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Pattern Insights'), findsOneWidget);
    expect(find.text('Educational Notes'), findsOneWidget);
    expect(find.text('When to Seek Care'), findsOneWidget);
  });
}
