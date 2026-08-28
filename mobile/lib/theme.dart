import 'package:flutter/material.dart';

/// CardioLens design tokens — kept in one place so the app and any future
/// screen stay visually consistent with the validated mockup, rather than
/// each screen picking its own colors.
class CardioLensColors {
  CardioLensColors._();

  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFDCE2EA);

  static const primary = Color(0xFF1D4E89);
  static const primaryDark = Color(0xFF123A66);

  static const textPrimary = Color(0xFF12203A);
  static const textSecondary = Color(0xFF6B7686);
  static const textMuted = Color(0xFF8891A0);

  static const alertBg = Color(0xFFFDECEA);
  static const alertBorder = Color(0xFFF3C6BC);
  static const alertText = Color(0xFF8A2A17);
  static const alertAccent = Color(0xFFB23B22);

  static const okBg = Color(0xFFE9F3EE);
  static const okText = Color(0xFF2F7A54);

  static const aiBg = Color(0xFFF2EEFA);
  static const aiBorder = Color(0xFFD9CDEF);
  static const aiText = Color(0xFF3D2A66);
  static const aiAccent = Color(0xFF5B3E96);

  static const ruleBadgeBg = Color(0xFF3B4A63);
}

ThemeData buildCardioLensTheme() {
  final base = ThemeData(useMaterial3: true, fontFamily: 'Roboto');
  return base.copyWith(
    scaffoldBackgroundColor: CardioLensColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: CardioLensColors.primary,
      surface: CardioLensColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CardioLensColors.surface,
      foregroundColor: CardioLensColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.5,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: CardioLensColors.textPrimary,
      displayColor: CardioLensColors.textPrimary,
    ),
    cardTheme: base.cardTheme.copyWith(
      color: CardioLensColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CardioLensColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CardioLensColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CardioLensColors.textPrimary,
        side: const BorderSide(color: Color(0xFFC7CEDA)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}
