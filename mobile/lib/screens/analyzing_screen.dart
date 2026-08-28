import 'package:flutter/material.dart';

import '../models/ecg_result.dart';
import '../theme.dart';
import 'results_screen.dart';

/// Shown briefly after "Importer un ECG". Today this just waits a fixed
/// delay before showing the picked sample case — there is no live backend
/// call yet (see EcgCase docs), so the step list below describes the
/// pipeline conceptually rather than reporting real progress.
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.resultCase});

  final EcgCase resultCase;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(ecgCase: widget.resultCase),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle analyse')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  color: CardioLensColors.primary,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Analyse en cours',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Lecture et interprétation du tracé ECG.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CardioLensColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              const _Step(label: 'Lecture du signal numérique', done: true),
              const _Step(label: 'Détection des ondes P / QRS / T', done: true),
              const _Step(
                label: 'Calcul des mesures (FC, PR, QRS, QTc)',
                done: true,
              ),
              const _Step(
                label: 'Application des règles cliniques',
                done: false,
              ),
              const _Step(
                label: 'Vérification IA sur cas complexes',
                done: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: done ? CardioLensColors.okText : CardioLensColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: done
                    ? CardioLensColors.textPrimary
                    : CardioLensColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
