import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:symptom_tracker/main.dart';
import 'package:symptom_tracker/services/app_backend.dart';
import 'package:symptom_tracker/services/local_symptom_repository.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    LocalSymptomRepository.useWebStorageForTesting = true;
  });

  testWidgets('first launch shows onboarding after splash',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    expect(find.text('Symptom Tracker'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Record symptoms clearly'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('How are you feeling today?'), findsOneWidget);
  });

  testWidgets('returning user sees redesigned log screen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboardingComplete': true});

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('How are you feeling today?'), findsOneWidget);
    expect(find.text('Pain Level'), findsOneWidget);
    expect(find.text('Body Area'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Mood'),
      find.byType(CustomScrollView),
      const Offset(0, -240),
    );
    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('log screen saves preview-visible fields',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({'onboardingComplete': true});
    await AppBackend.repository.init();

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Head'),
      find.byType(CustomScrollView),
      const Offset(0, -260),
    );
    await tester.tap(
      find.ancestor(of: find.text('Head'), matching: find.byType(ChoiceChip)),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Calm'),
      find.byType(CustomScrollView),
      const Offset(0, -260),
    );
    await tester.tap(
      find.ancestor(of: find.text('Calm'), matching: find.byType(ChoiceChip)),
    );
    await tester.pumpAndSettle();

    final notesField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText ==
              'Add any additional details about how you feel...',
    );
    await tester.dragUntilVisible(
      notesField,
      find.byType(CustomScrollView),
      const Offset(0, -260),
    );
    await tester.enterText(notesField, 'Redesign save test note');

    await tester.dragUntilVisible(
      find.text('Save Entry'),
      find.byType(CustomScrollView),
      const Offset(0, -260),
    );
    await tester.tap(find.text('Save Entry'));
    await tester.pumpAndSettle();

    final entries = await DatabaseHelper.getEntries();
    final saved = entries.firstWhere(
      (entry) => entry['notes'] == 'Redesign save test note',
    );
    expect(saved['body_area'], 'Head');
    expect(saved['mood'], 'Calm');
    expect(saved['custom_symptoms'], '');
    expect(saved['temperature_celsius'], isNull);
  });

  test('web storage map shape does not crash repository reads', () async {
    SharedPreferences.setMockInitialValues({'mar_local_entries': '{}'});
    final repository = LocalSymptomRepository();
    await repository.init();

    final entries = await repository.getEntries();

    expect(entries, isEmpty);
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

  testWidgets('insights screen auto shows combined AI analysis',
      (tester) async {
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

    expect(find.text('AI Analysis'), findsOneWidget);
    expect(find.text('Health Pattern Analysis'), findsOneWidget);
    expect(find.text('Quick Stats'), findsOneWidget);
    expect(find.byTooltip('Generate AI insight'), findsNothing);
  });
}
