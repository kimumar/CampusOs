import 'campus_pulse_calculator.dart';

/// One definition of academic completion, shared by dashboard and upload.
/// A day with no assigned goals is zero achievement, never a free 100%.
class AcademicProgressEngine {
  AcademicProgressEngine._();

  static CampusPulseSnapshot calculate(Iterable<List<Map<String, dynamic>>> days) =>
      CampusPulseSnapshot.fromSavedDays(days);

  static Map<String, dynamic> uploadDay(String date, List<Map<String, dynamic>> missions) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      throw const FormatException('Invalid study date');
    }
    final snapshot = calculate([missions]);
    return <String, dynamic>{
      'date': date,
      'assigned': snapshot.assigned,
      'completed': snapshot.completed,
    };
  }
}
