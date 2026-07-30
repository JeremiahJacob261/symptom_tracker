/// Converts the app's structured symptom log into language that is closer to
/// the natural-language Symptom2Disease examples used by the classifier.
class SymptomDetailPrompt {
  const SymptomDetailPrompt({
    required this.id,
    required this.label,
    required this.hint,
    required this.symptoms,
  });

  final String id;
  final String label;
  final String hint;
  final Set<String> symptoms;
}

class SymptomModelInput {
  static const prompts = <SymptomDetailPrompt>[
    SymptomDetailPrompt(
      id: 'fever_details',
      label: 'Fever details (optional)',
      hint: 'How long, sweating/chills, appetite, or measured temperature',
      symptoms: {'Fever', 'Chills', 'Fatigue', 'Body aches'},
    ),
    SymptomDetailPrompt(
      id: 'head_details',
      label: 'Head symptom details (optional)',
      hint: 'Onset, vision changes, light sensitivity, or neck stiffness',
      symptoms: {'Headache', 'Dizziness', 'Confusion', 'Numbness'},
    ),
    SymptomDetailPrompt(
      id: 'respiratory_details',
      label: 'Breathing/cough details (optional)',
      hint: 'Cough type, phlegm, wheezing, or breathing changes',
      symptoms: {'Cough', 'Shortness of breath', 'Sore throat', 'Wheezing'},
    ),
    SymptomDetailPrompt(
      id: 'digestive_details',
      label: 'Digestive details (optional)',
      hint: 'Pain location, bowel changes, heartburn/reflux, or vomiting',
      symptoms: {'Nausea', 'Vomiting', 'Diarrhea/Stooling', 'Stomach ache'},
    ),
    SymptomDetailPrompt(
      id: 'skin_details',
      label: 'Skin details (optional)',
      hint: 'Location, itchiness, scaling, blisters, crusting, or spread',
      symptoms: {'Rash', 'Itching', 'Swelling', 'Bruising'},
    ),
    SymptomDetailPrompt(
      id: 'joint_details',
      label: 'Muscle/joint details (optional)',
      hint: 'Affected joint, stiffness, swelling, or movement impact',
      symptoms: {'Joint pain', 'Muscle pain', 'Back pain', 'Stiffness'},
    ),
  ];

  static const _canonicalTerms = <String, String>{
    'Fever': 'fever',
    'Fatigue': 'fatigue and tiredness',
    'Chills': 'chills',
    'Body aches': 'body aches and muscle pain',
    'Headache': 'headache',
    'Dizziness': 'dizziness',
    'Confusion': 'confusion',
    'Numbness': 'numbness',
    'Cough': 'cough',
    'Shortness of breath': 'shortness of breath',
    'Sore throat': 'sore throat',
    'Wheezing': 'wheezing',
    'Chest discomfort': 'chest pain or discomfort',
    'Palpitations': 'heart palpitations',
    'Fainting': 'fainting',
    'Swelling': 'swelling',
    'Nausea': 'nausea',
    'Vomiting': 'vomiting',
    'Diarrhea/Stooling': 'diarrhea or loose stools',
    'Stomach ache': 'abdominal pain or stomach ache',
    'Joint pain': 'joint pain',
    'Muscle pain': 'muscle pain',
    'Back pain': 'back pain',
    'Stiffness': 'stiffness',
    'Rash': 'skin rash',
    'Itching': 'itching',
    'Bruising': 'bruising',
    'Anxiety': 'anxiety',
    'Low mood': 'low mood',
    'Irritability': 'irritability',
    'Poor sleep': 'poor sleep',
  };

  static List<SymptomDetailPrompt> promptsFor(Set<String> selected) => prompts
      .where((prompt) => prompt.symptoms.any(selected.contains))
      .toList(growable: false);

  static String build({
    required Iterable<String> symptoms,
    String? bodyArea,
    String? customSymptoms,
    String? notes,
    Map<String, String> details = const {},
    double? temperatureCelsius,
  }) {
    final parts = <String>[];
    final translated = symptoms
        .map((symptom) => _canonicalTerms[symptom] ?? symptom.toLowerCase())
        .toList();
    if (translated.isNotEmpty) {
      parts.add('I am experiencing ${translated.join(', ')}.');
    }
    if (bodyArea != null && bodyArea.trim().isNotEmpty) {
      parts.add('The affected area is ${bodyArea.trim().toLowerCase()}.');
    }
    if (temperatureCelsius != null) {
      parts.add(
        'My measured temperature is ${temperatureCelsius.toStringAsFixed(1)} degrees Celsius.',
      );
    }
    void add(String? value) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) parts.add(text);
    }

    add(customSymptoms);
    for (final value in details.values) {
      add(value);
    }
    add(notes);
    return parts.join(' ');
  }
}
