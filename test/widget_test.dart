import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organisr/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('OrganiSR app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OrganiSRApp());
    await tester.pump();
    expect(find.byType(OrganiSRApp), findsOneWidget);

    // Tap to enter immediately via interactive splash
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('OrganiSR'), findsWidgets);
  });
}
