import 'package:flutter_test/flutter_test.dart';
import 'package:symptom_tracker/services/symptom_model_input.dart';

void main() {
  test('adapter translates button labels into model-friendly symptom text', () {
    final text = SymptomModelInput.build(
      symptoms: const ['Fever', 'Diarrhea/Stooling', 'Stomach ache'],
      bodyArea: 'Chest',
      customSymptoms: 'burning when urinating',
      notes: 'Started yesterday.',
      details: const {
        'digestive_details': 'I also have heartburn after meals.'
      },
      temperatureCelsius: 38.2,
    );

    expect(text, contains('fever'));
    expect(text, contains('diarrhea or loose stools'));
    expect(text, contains('abdominal pain or stomach ache'));
    expect(text, contains('affected area is chest'));
    expect(text, contains('38.2 degrees Celsius'));
    expect(text, contains('heartburn after meals'));
    expect(text, contains('burning when urinating'));
  });

  test('adaptive prompts only appear for matching symptom groups', () {
    final prompts = SymptomModelInput.promptsFor({'Rash', 'Itching'});

    expect(prompts.map((prompt) => prompt.id), contains('skin_details'));
    expect(prompts.map((prompt) => prompt.id),
        isNot(contains('digestive_details')));
  });
}
