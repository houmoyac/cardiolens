import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/main_tab_screen.dart';
import 'services/auth_service.dart';
import 'theme.dart';

void main() {
  runApp(const CardioLensApp());
}

class CardioLensApp extends StatelessWidget {
  const CardioLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardioLens',
      debugShowCheckedModeBanner: false,
      theme: buildCardioLensTheme(),
      home: const _AuthGate(),
    );
  }
}

/// Resumes a stored session (if any) before showing the app — see
/// AuthService.restoreSession for what "resume" means when the backend is
/// unreachable vs. when the token is actually invalid.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<bool> _restoring = AuthService.instance.restoreSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _restoring,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: CardioLensColors.primary),
            ),
          );
        }
        return snapshot.data == true ? const MainTabScreen() : const LoginScreen();
      },
    );
  }
}
