import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusos_mobile/main.dart';

void main() {
  testWidgets('CampusOS home screen displays correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CampusOSApp());

    expect(find.text('CampusOS'), findsOneWidget);

    expect(
      find.text('Your academic comeback starts here.'),
      findsOneWidget,
    );

    expect(
      find.text("Don't just read. Remember what you study."),
      findsOneWidget,
    );

    expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
  });
}