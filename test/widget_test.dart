import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_press/main.dart';

void main() {
  testWidgets('DigitalPress app launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DigitalPressApp(),
      ),
    );

    // Verify that the app renders without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
