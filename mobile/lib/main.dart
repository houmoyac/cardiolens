import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
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
      home: const HomeScreen(),
    );
  }
}
