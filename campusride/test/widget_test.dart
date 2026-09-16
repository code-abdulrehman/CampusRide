import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:campusride/app.dart';
import 'package:campusride/providers/app_state_provider.dart';

void main() {
  testWidgets('App boots to splash then shows login', (WidgetTester tester) async {
    final state = AppStateProvider();
    state.repository.seedDemoData();

    await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const CampusRideApp()));

    expect(find.text('CampusRide'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back!'), findsOneWidget);
  });

  testWidgets('Smart matching scores rides for the demo request', (WidgetTester tester) async {
    final state = AppStateProvider();
    state.repository.seedDemoData();

    final matches = state.repository.findMatchingRides(
      fromCampusId: 'campus_a',
      toCampusId: 'main',
      date: DateTime.now().add(const Duration(days: 1)),
      startTime: const TimeOfDay(hour: 7, minute: 45),
      endTime: const TimeOfDay(hour: 8, minute: 30),
      budget: 250,
      seatsNeeded: 1,
    );

    expect(matches, isNotEmpty);
    expect(matches.first.value, greaterThanOrEqualTo(70));
  });
}