class AppointmentEntry {
  final int? id;
  final String doctorName;
  final String specialty;
  final DateTime dateTime;
  final String location;
  final String? notes;
  final bool isCompleted;

  AppointmentEntry({
    this.id,
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    required this.location,
    this.notes,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctorName': doctorName,
      'specialty': specialty,
      'dateTime': dateTime.toIso8601String(),
      'location': location,
      'notes': notes,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory AppointmentEntry.fromMap(Map<String, dynamic> map) {
    return AppointmentEntry(
      id: map['id'] as int?,
      doctorName: map['doctorName'] as String,
      specialty: map['specialty'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
      location: map['location'] as String,
      notes: map['notes'] as String?,
      isCompleted: map['isCompleted'] == 1,
    );
  }
}
