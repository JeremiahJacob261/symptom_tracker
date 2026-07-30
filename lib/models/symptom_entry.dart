class SymptomEntry {
  final int? id;
  final DateTime date;
  final int painLevel;
  final String mood;
  final String bodyArea;
  final String notes;
  final List<String>? symptoms;
  final String? imagePath;

  SymptomEntry({
    this.id,
    required this.date,
    required this.painLevel,
    required this.mood,
    required this.bodyArea,
    required this.notes,
    this.symptoms,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'painLevel': painLevel,
      'mood': mood,
      'bodyArea': bodyArea,
      'notes': notes,
      'symptoms': symptoms?.join(','),
      'imagePath': imagePath,
    };
  }

  factory SymptomEntry.fromMap(Map<String, dynamic> map) {
    return SymptomEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      painLevel: map['painLevel'] as int,
      mood: map['mood'] as String,
      bodyArea: map['bodyArea'] as String,
      notes: map['notes'] as String,
      symptoms: map['symptoms'] != null
          ? (map['symptoms'] as String).split(',')
          : null,
      imagePath: map['imagePath'] as String?,
    );
  }
}
