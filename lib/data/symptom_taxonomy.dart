import 'dart:convert';

class SymptomCategory {
  const SymptomCategory({
    required this.name,
    required this.symptoms,
  });

  final String name;
  final List<String> symptoms;
}

const symptomCategories = [
  SymptomCategory(
    name: 'General',
    symptoms: ['Fever', 'Fatigue', 'Chills', 'Body aches'],
  ),
  SymptomCategory(
    name: 'Head and Neurological',
    symptoms: ['Headache', 'Dizziness', 'Confusion', 'Numbness'],
  ),
  SymptomCategory(
    name: 'Respiratory',
    symptoms: ['Cough', 'Shortness of breath', 'Sore throat', 'Wheezing'],
  ),
  SymptomCategory(
    name: 'Cardiovascular',
    symptoms: ['Chest discomfort', 'Palpitations', 'Fainting', 'Swelling'],
  ),
  SymptomCategory(
    name: 'Digestive',
    symptoms: ['Nausea', 'Vomiting', 'Diarrhea/Stooling', 'Stomach ache'],
  ),
  SymptomCategory(
    name: 'Musculoskeletal',
    symptoms: ['Joint pain', 'Muscle pain', 'Back pain', 'Stiffness'],
  ),
  SymptomCategory(
    name: 'Skin',
    symptoms: ['Rash', 'Itching', 'Swelling', 'Bruising'],
  ),
  SymptomCategory(
    name: 'Mental and Emotional',
    symptoms: ['Anxiety', 'Low mood', 'Irritability', 'Poor sleep'],
  ),
];

List<String> readEntrySymptoms(Map<String, dynamic> entry) {
  final value = entry['symptoms_json'] ?? entry['symptoms'];
  if (value == null) return const [];
  if (value is List) return value.map((item) => item.toString()).toList();
  final raw = value.toString().trim();
  if (raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList();
    }
  } catch (_) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

String readCustomSymptoms(Map<String, dynamic> entry) {
  return (entry['custom_symptoms'] ?? '').toString().trim();
}

double? readTemperatureCelsius(Map<String, dynamic> entry) {
  final value = entry['temperature_celsius'];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

double celsiusFromInput(double value, String unit) {
  return unit == 'F' ? (value - 32) * 5 / 9 : value;
}

double displayTemperature(double celsius, String unit) {
  return unit == 'F' ? (celsius * 9 / 5) + 32 : celsius;
}

String formatTemperature(double? celsius, {String unit = 'C'}) {
  if (celsius == null) return 'Not recorded';
  final value = displayTemperature(celsius, unit);
  return '${value.toStringAsFixed(1)} deg $unit';
}
