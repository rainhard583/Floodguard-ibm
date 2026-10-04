import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('FloodGuard basic widget smoke test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('FloodGuard'),
        ),
      ),
    );

    expect(find.text('FloodGuard'), findsOneWidget);
  });
}
