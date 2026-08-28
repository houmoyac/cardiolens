import 'package:flutter/material.dart';

import '../data/sample_cases.dart';
import '../models/ecg_result.dart';
import '../theme.dart';
import 'analyzing_screen.dart';
import 'results_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CardioLens'),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: CardioLensColors.textPrimary,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Aide à l'interprétation ECG",
            style: TextStyle(
              color: CardioLensColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          _ImportButton(
            icon: Icons.file_upload_outlined,
            title: 'Importer un ECG',
            subtitle: 'Fichier numérique (CSV pour le moment)',
            filled: true,
            onTap: () => _startAnalysis(context, sampleCases.first),
          ),
          const SizedBox(height: 10),
          _ImportButton(
            icon: Icons.camera_alt_outlined,
            title: 'Scanner via photo',
            subtitle: 'Bientôt disponible',
            filled: false,
            enabled: false,
            onTap: () {},
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Analyses récentes',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                'Exemples PTB-XL',
                style: TextStyle(
                  color: CardioLensColors.primary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final ecgCase in sampleCases) ...[
            _RecentCaseTile(
              ecgCase: ecgCase,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ResultsScreen(ecgCase: ecgCase),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  void _startAnalysis(BuildContext context, EcgCase demoCase) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnalyzingScreen(resultCase: demoCase)),
    );
  }
}

class _ImportButton extends StatelessWidget {
  const _ImportButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : CardioLensColors.textPrimary;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: filled ? CardioLensColors.primary : CardioLensColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: filled
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CardioLensColors.border),
                  ),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: filled
                              ? Colors.white.withValues(alpha: 0.75)
                              : CardioLensColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentCaseTile extends StatelessWidget {
  const _RecentCaseTile({required this.ecgCase, required this.onTap});

  final EcgCase ecgCase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ok = !ecgCase.hasWarning;
    return Material(
      color: CardioLensColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CardioLensColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: ok ? CardioLensColors.okBg : CardioLensColors.alertBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.monitor_heart_outlined,
                  size: 16,
                  color: ok
                      ? CardioLensColors.okText
                      : CardioLensColors.alertAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ecgCase.patientLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      ecgCase.dateLabel,
                      style: const TextStyle(
                        color: CardioLensColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ok ? CardioLensColors.okBg : CardioLensColors.alertBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ok ? 'Normal' : 'Anomalie',
                  style: TextStyle(
                    color: ok
                        ? CardioLensColors.okText
                        : CardioLensColors.alertAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
