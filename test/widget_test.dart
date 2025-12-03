// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tryb_ludo_v1/main.dart';

void main() {
  testWidgets('Smoke test: app builds', (WidgetTester tester) async {
    // ❌ remove const — MyApp is NOT const
    await tester.pumpWidget(MyApp());

    // simple assertion
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
