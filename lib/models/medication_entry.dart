class MedicationEntry {
  final int? id;
  final String name;
  final String dosage;
  final String frequency;
  final String time;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;

  MedicationEntry({
    this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.time,
    this.isActive = true,
    required this.startDate,
    this.endDate,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'time': time,
      'isActive': isActive ? 1 : 0,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'notes': notes,
    };
  }

  factory MedicationEntry.fromMap(Map<String, dynamic> map) {
    return MedicationEntry(
      id: map['id'] as int?,
      name: map['name'] as String,
      dosage: map['dosage'] as String,
      frequency: map['frequency'] as String,
      time: map['time'] as String,
      isActive: map['isActive'] == 1,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      notes: map['notes'] as String?,
    );
  }
}
