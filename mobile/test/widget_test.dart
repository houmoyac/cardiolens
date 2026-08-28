import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cardiolens_app/main.dart';
import 'package:cardiolens_app/screens/home_screen.dart';
import 'package:cardiolens_app/screens/login_screen.dart';
import 'package:cardiolens_app/screens/results_screen.dart';
import 'package:cardiolens_app/theme.dart';

/// These tests exercise HomeScreen directly (not through CardioLensApp) so
/// they don't depend on authentication state — see the AuthGate test below
/// for that. HomeScreen has no dependency on being logged in except the
/// account menu, which isn't touched here.
Widget _wrapped(Widget child) =>
    MaterialApp(theme: buildCardioLensTheme(), home: child);

void main() {
  testWidgets('Home screen shows title and sample cases', (tester) async {
    await tester.pumpWidget(_wrapped(const HomeScreen()));

    expect(find.text('CardioLens'), findsOneWidget);
    expect(find.text('Patient #A-2288'), findsOneWidget);
    expect(find.text('Patient #A-2291'), findsOneWidget);
    expect(find.text('Patient #A-2279'), findsOneWidget);
  });

  testWidgets('Tapping a recent case opens the results screen', (tester) async {
    await tester.pumpWidget(_wrapped(const HomeScreen()));

    await tester.tap(find.text('Patient #A-2291'));
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.textContaining('Bradycardie'), findsOneWidget);
  });

  testWidgets('Importing opens a demo-case picker, then shows a real API error '
      '(Flutter test env blocks real HTTP — this exercises the honest '
      'error path, not a silent fallback)', (tester) async {
    await tester.pumpWidget(_wrapped(const HomeScreen()));

    await tester.tap(find.text('Importer un ECG'));
    await tester.pumpAndSettle();

    // The sheet's ListTile is the only widget of that type showing this
    // text — the home screen's recent-case tiles use a different widget —
    // so this unambiguously targets the picker, not the list behind it.
    await tester.tap(find.widgetWithText(ListTile, 'Patient #A-2288'));
    // Two pumps: the new route is briefly marked offstage for exactly one
    // zero-duration frame (Flutter avoids a flash while the push
    // transition starts) — a single pump(duration) alone doesn't clear
    // that flag.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // The real network call fails in the test environment — the app
    // must show an explicit error, never silently swap in fake data.
    expect(find.text('Réessayer'), findsOneWidget);
    expect(
      find.text('Continuer avec des données de démo (pas un vrai résultat)'),
      findsOneWidget,
    );

    await tester.tap(
      find.text('Continuer avec des données de démo (pas un vrai résultat)'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ResultsScreen), findsOneWidget);
  });

  testWidgets(
    'With no stored session, the app opens on the login screen '
    '(secure storage is unavailable in the test env, which restoreSession '
    'treats the same as "nothing stored", not a crash)',
    (tester) async {
      await tester.pumpWidget(const CardioLensApp());
      // Not pumpAndSettle: the loading state is a CircularProgressIndicator,
      // an indefinite animation that never "settles" on its own. Advance
      // past AuthService.restoreSession's 3s secure-storage read timeout.
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );
}
