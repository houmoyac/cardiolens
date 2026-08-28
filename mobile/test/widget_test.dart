import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cardiolens_app/main.dart';
import 'package:cardiolens_app/screens/results_screen.dart';

void main() {
  testWidgets('Home screen shows title and sample cases', (tester) async {
    await tester.pumpWidget(const CardioLensApp());

    expect(find.text('CardioLens'), findsOneWidget);
    expect(find.text('Patient #A-2288'), findsOneWidget);
    expect(find.text('Patient #A-2291'), findsOneWidget);
    expect(find.text('Patient #A-2279'), findsOneWidget);
  });

  testWidgets('Tapping a recent case opens the results screen', (tester) async {
    await tester.pumpWidget(const CardioLensApp());

    await tester.tap(find.text('Patient #A-2291'));
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.textContaining('Bradycardie'), findsOneWidget);
  });

  testWidgets('Importing opens a demo-case picker, then shows a real API error '
      '(Flutter test env blocks real HTTP — this exercises the honest '
      'error path, not a silent fallback)', (tester) async {
    await tester.pumpWidget(const CardioLensApp());

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
}
