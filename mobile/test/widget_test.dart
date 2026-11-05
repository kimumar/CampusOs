import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CampusOS widget test environment works', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('CampusOS'),
        ),
      ),
    );

    expect(find.text('CampusOS'), findsOneWidget);
  });
}