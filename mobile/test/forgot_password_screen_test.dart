import 'package:cardiolens_app/screens/forgot_password_screen.dart';
import 'package:cardiolens_app/screens/login_screen.dart';
import 'package:cardiolens_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapped(Widget child) => MaterialApp(theme: buildCardioLensTheme(), home: child);

void main() {
  testWidgets(
    'Login screen offers a way to the forgot-password flow, which is '
    'honest about email delivery not being configured yet',
    (tester) async {
      await tester.pumpWidget(_wrapped(const LoginScreen()));

      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(
        find.textContaining("n'est pas encore configuré"),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'The forgot-password link is hidden while creating an account '
    '(nothing to reset yet)',
    (tester) async {
      await tester.pumpWidget(_wrapped(const LoginScreen()));

      await tester.tap(find.text('Pas encore de compte ? En créer un'));
      await tester.pump();

      expect(find.text('Mot de passe oublié ?'), findsNothing);
    },
  );
}
