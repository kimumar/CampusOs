import 'package:flutter_test/flutter_test.dart';
import 'package:campusos_mobile/services/check_in_storage.dart';

void main() {
  final today = DateTime(2026, 11, 10);
  test('checking in is separate from study activity', () {
    expect(CheckInStorage.streakFromDays({'2026-11-10'}, today), 1);
  });
  test('one missed day bridges without increasing the earned count', () {
    expect(CheckInStorage.streakFromDays({'2026-11-10','2026-11-08'}, today), 2);
    expect(CheckInStorage.streakFromDays({'2026-11-10','2026-11-07'}, today), 1);
  });
  test('no check-ins means zero streak', () {
    expect(CheckInStorage.streakFromDays(<String>{}, today), 0);
  });
}
