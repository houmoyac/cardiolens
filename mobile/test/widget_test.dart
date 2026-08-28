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

  testWidgets('Importing navigates through analyzing to results', (
    tester,
  ) async {
    await tester.pumpWidget(const CardioLensApp());

    await tester.tap(find.text('Importer un ECG'));
    // Two pumps: the new route is briefly marked offstage for exactly one
    // zero-duration frame (Flutter avoids a flash while the push transition
    // starts) — a single pump(duration) alone doesn't clear that flag.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Analyse en cours'), findsOneWidget);

    await tester.pump(
      const Duration(seconds: 2),
    ); // past the auto-navigate delay
    await tester.pumpAndSettle();
    expect(find.byType(ResultsScreen), findsOneWidget);
  });
}
