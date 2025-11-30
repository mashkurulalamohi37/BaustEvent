// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baust_event/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App initializes correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: Firebase initialization may fail in test environment, but the app handles this gracefully
    await tester.pumpWidget(const EventBridgeApp());
    
    // Allow time for async initialization and theme loading
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    
    // Verify that the app loads (should show MaterialApp)
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Pump frames to allow any pending async operations to complete or timeout
    // This ensures the test doesn't fail due to pending timers
    await tester.pump(const Duration(seconds: 7)); // Wait for auth timeout + buffer
    await tester.pump(); // Final pump to clear any pending operations
  });
}
