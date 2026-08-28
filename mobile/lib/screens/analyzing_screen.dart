import 'package:flutter/material.dart';

import '../models/ecg_result.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../theme.dart';
import 'results_screen.dart';

/// Shown after "Importer un ECG". If the picked case has a bundled signal
/// (see EcgCase.signalAssetPath), this sends it to the real backend and
/// shows its real response — the first part of the app not using static
/// sample data. On failure (backend unreachable, phone off the Mac's
/// WiFi, ...) it shows an explicit error, never a silent fallback to
/// fake data — the physician must always know which they're looking at.
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.resultCase});

  final EcgCase resultCase;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() => _error = null);

    final assetPath = widget.resultCase.signalAssetPath;
    if (assetPath == null) {
      await Future.delayed(const Duration(milliseconds: 1400));
      _goToResults(widget.resultCase);
      return;
    }

    try {
      final signal = await loadBundledSignal(assetPath);
      final client = ApiClient(baseUrl: apiBaseUrl);
      final result = await client.analyze(
        patientLabel: widget.resultCase.patientLabel,
        dateLabel: widget.resultCase.dateLabel,
        signal: signal,
        samplingRateHz: widget.resultCase.samplingRateHz,
      );
      _goToResults(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _goToResults(EcgCase ecgCase) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultsScreen(ecgCase: ecgCase)),
    );
  }

  void _continueWithFallbackData() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(ecgCase: widget.resultCase),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle analyse')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: _error != null
              ? _ErrorState(
                  message: _error!,
                  onRetry: _analyze,
                  onUseFallback: _continueWithFallbackData,
                )
              : Column(
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
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Envoi au serveur et interprétation du tracé ECG.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CardioLensColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onUseFallback,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onUseFallback;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off,
          size: 40,
          color: CardioLensColors.alertAccent,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            color: CardioLensColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onUseFallback,
          child: const Text(
            'Continuer avec des données de démo (pas un vrai résultat)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: CardioLensColors.textMuted),
          ),
        ),
      ],
    );
  }
}
