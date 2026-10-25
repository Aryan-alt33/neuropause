import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuropause/main.dart';
import 'package:neuropause/mindful_break_screen.dart';
import 'package:neuropause/mood_check_screen.dart';
import 'package:neuropause/notification_pause_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'Full navigation and features: Notification Pause, Mindful Break, and Mood Check',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NeuroPauseApp());

    // Verify Home Screen elements
    expect(find.text('NeuroPause'), findsOneWidget);
    expect(find.text('Make space for your mind.'), findsOneWidget);
    expect(find.text('Your personal digital wellbeing companion.'), findsOneWidget);
    expect(find.text('Notification Pause'), findsOneWidget);
    expect(find.text('Take a Mindful Break'), findsOneWidget);
    expect(find.text('Mood Check'), findsOneWidget);
    expect(find.text('Your attention matters 🌿'), findsOneWidget);

    // ==========================================
    // 1. TEST NOTIFICATION PAUSE SCREEN
    // ==========================================
    await tester.tap(find.text('Notification Pause'));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationPauseScreen), findsOneWidget);
    expect(find.text('Pause is Active'), findsOneWidget);
    expect(find.text('Incoming Feed'), findsOneWidget);

    // Back to Home Screen
    final backButton = find.byTooltip('Back');
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // ==========================================
    // 2. TEST MINDFUL BREAK SCREEN
    // ==========================================
    await tester.tap(find.text('Take a Mindful Break'));
    await tester.pumpAndSettle();

    expect(find.byType(MindfulBreakScreen), findsOneWidget);
    expect(find.text('Take a Mindful Break'), findsOneWidget);
    expect(find.text('60-Second Reset'), findsOneWidget);

    // Start session
    await tester.ensureVisible(find.text('Start 60s Break'));
    await tester.tap(find.text('Start 60s Break'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('00:59'), findsOneWidget);

    // Back to Home Screen
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // ==========================================
    // 3. TEST MOOD CHECK SCREEN
    // ==========================================
    await tester.ensureVisible(find.text('Mood Check'));
    await tester.tap(find.text('Mood Check'));
    await tester.pumpAndSettle();

    expect(find.byType(MoodCheckScreen), findsOneWidget);
    expect(find.text('Mood Check'), findsOneWidget);
    expect(find.text('How are you feeling right now?'), findsOneWidget);

    // Verify 5 mood options are present
    expect(find.text('Happy'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Okay'), findsOneWidget);
    expect(find.text('Anxious'), findsOneWidget);
    expect(find.text('Overwhelmed'), findsOneWidget);

    // Select 'Calm' mood
    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    // Verify CBT question and reflection card appears
    expect(find.text('Reflection for Calm'), findsOneWidget);
    expect(find.text('Save Reflection'), findsOneWidget);

    // Enter reflection text
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(
        textField, 'Feeling centered after a quiet breathing moment.');
    await tester.pump();

    // Tap Save Reflection
    await tester.ensureVisible(find.text('Save Reflection'));
    await tester.tap(find.text('Save Reflection'));
    await tester.pumpAndSettle();

    // Verify reflection saved in Past Reflections list
    expect(find.text('Past Reflections'), findsOneWidget);
    expect(
      find.text('Feeling centered after a quiet breathing moment.'),
      findsOneWidget,
    );

    // Back to Home Screen
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);

    // Re-open Mood Check (simulating refresh / re-entry)
    await tester.ensureVisible(find.text('Mood Check'));
    await tester.tap(find.text('Mood Check'));
    await tester.pumpAndSettle();

    // Verify previously saved reflection is loaded from SharedPreferences
    expect(find.text('Past Reflections'), findsOneWidget);
    expect(
      find.text('Feeling centered after a quiet breathing moment.'),
      findsOneWidget,
    );
  });
}
