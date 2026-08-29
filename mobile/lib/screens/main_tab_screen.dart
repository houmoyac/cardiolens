import 'package:flutter/material.dart';

import '../theme.dart';
import 'analysis_history_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Root screen once logged in — bottom tab navigation (Accueil / Historique
/// / Profil). IndexedStack, not a fresh Navigator push per tab, so each
/// tab keeps its own scroll position/state when switching back to it.
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    AnalysisHistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        backgroundColor: CardioLensColors.surface,
        indicatorColor: CardioLensColors.primary.withValues(alpha: 0.1),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
