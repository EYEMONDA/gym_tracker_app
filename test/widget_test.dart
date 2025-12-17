// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:gym_tracker_app/main.dart';

void main() {
  testWidgets('App builds and shows tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const GymTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Workout'), findsWidgets);
    expect(find.text('Log'), findsWidgets);
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Progress'), findsWidgets);
    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    // Settings sub-tabs exist.
    expect(find.text('General'), findsWidgets);
    expect(find.text('Experimental'), findsWidgets);
  });
}
