import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:campusride/providers/app_state_provider.dart';
import 'package:campusride/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders the sign-in form', (WidgetTester tester) async {
    final state = AppStateProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Demo accounts'), findsOneWidget);
  });

  testWidgets('Login screen shows error on empty credentials', (WidgetTester tester) async {
    final state = AppStateProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    final emailField = find.byType(TextField).at(0);
    await tester.enterText(emailField, '');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Enter your email and password.'), findsOneWidget);
  });
}