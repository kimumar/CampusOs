import 'package:flutter_test/flutter_test.dart';
import 'package:campusos_mobile/services/profile_storage.dart';

void main() {
  test('academic identity requires institution, department and level', () {
    expect(const StudentProfile().complete, isFalse);
    expect(const StudentProfile(institution: 'University', department: 'Engineering', level: '200 Level').complete, isTrue);
    expect(const StudentProfile(institution: 'University', level: '200 Level').complete, isFalse);
    expect(const StudentProfile(institution: 'University', department: 'Engineering').complete, isFalse);
    expect(const StudentProfile(institution: '  ', department: 'Engineering', level: '200 Level').complete, isFalse);
  });
  test('name and photo are optional', () {
    const profile = StudentProfile(institution: 'University', department: 'Engineering', level: '200 Level');
    expect(profile.complete, isTrue);
    expect(profile.name, isEmpty);
    expect(profile.photo, isNull);
  });
}
