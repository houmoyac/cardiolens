import 'package:cardiolens_app/screens/analysis_history_screen.dart';
import 'package:cardiolens_app/screens/home_screen.dart';
import 'package:cardiolens_app/screens/main_tab_screen.dart';
import 'package:cardiolens_app/screens/profile_screen.dart';
import 'package:cardiolens_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapped(Widget child) => MaterialApp(theme: buildCardioLensTheme(), home: child);

void main() {
  testWidgets('Starts on the Accueil tab', (tester) async {
    await tester.pumpWidget(_wrapped(const MainTabScreen()));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AnalysisHistoryScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('Tapping Historique switches to the history tab', (tester) async {
    await tester.pumpWidget(_wrapped(const MainTabScreen()));

    await tester.tap(find.text('Historique'));
    await tester.pump();

    expect(find.byType(AnalysisHistoryScreen), findsOneWidget);
  });

  testWidgets('Tapping Profil switches to the profile tab', (tester) async {
    await tester.pumpWidget(_wrapped(const MainTabScreen()));

    await tester.tap(find.text('Profil'));
    await tester.pump();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
