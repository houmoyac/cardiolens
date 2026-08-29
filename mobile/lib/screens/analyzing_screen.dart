import 'package:flutter/material.dart';

import '../models/ecg_result.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../theme.dart';
import 'results_screen.dart';

/// A real file the doctor picked ("Importer un ECG"), already parsed
/// client-side into a raw signal — see AnalyzingScreen.realImport. Unlike
/// a demo EcgCase, there is no legitimate fallback data for this: if
/// analysis fails, the only honest options are retry or cancel.
class RealEcgImport {
  const RealEcgImport({
    required this.patientLabel,
    required this.dateLabel,
    required this.signal,
    required this.samplingRateHz,
    this.sex,
  });

  final String patientLabel;
  final String dateLabel;
  final List<double> signal;
  final int samplingRateHz;
  final String? sex;
}

/// Shown after "Importer un ECG". Two modes:
/// - A bundled demo case (see EcgCase.signalAssetPath): sends the bundled
///   signal to the real backend, with a "continue with demo data" fallback
///   if that fails — the demo case's static measurements are a legitimate
///   stand-in there, since they were never claimed to be a real result.
/// - A real file the doctor picked (RealEcgImport): same real backend
///   call, but NO fallback on failure — there is no fake data that would
///   be honest to show for a file the doctor actually brought in.
/// Either way, failure always shows an explicit error, never a silent
/// swap to fake data — the physician must always know which they're
/// looking at.
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required EcgCase demoCase})
    : resultCase = demoCase,
      realImport = null;

  const AnalyzingScreen.realImport({super.key, required RealEcgImport import})
    : resultCase = null,
      realImport = import;

  final EcgCase? resultCase;
  final RealEcgImport? realImport;

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

    final realImport = widget.realImport;
    if (realImport != null) {
      try {
        final client = ApiClient(baseUrl: apiBaseUrl);
        final result = await client.analyze(
          patientLabel: realImport.patientLabel,
          dateLabel: realImport.dateLabel,
          signal: realImport.signal,
          samplingRateHz: realImport.samplingRateHz,
          sex: realImport.sex,
        );
        _goToResults(result);
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      }
      return;
    }

    final resultCase = widget.resultCase!;
    final assetPath = resultCase.signalAssetPath;
    if (assetPath == null) {
      await Future.delayed(const Duration(milliseconds: 1400));
      _goToResults(resultCase);
      return;
    }

    try {
      final signal = await loadBundledSignal(assetPath);
      final client = ApiClient(baseUrl: apiBaseUrl);
      final result = await client.analyze(
        patientLabel: resultCase.patientLabel,
        dateLabel: resultCase.dateLabel,
        signal: signal,
        samplingRateHz: resultCase.samplingRateHz,
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
    final resultCase = widget.resultCase;
    if (resultCase == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultsScreen(ecgCase: resultCase)),
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
                  onUseFallback: widget.resultCase != null ? _continueWithFallbackData : null,
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
  final VoidCallback? onUseFallback;

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
        if (onUseFallback != null) ...[
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
      ],
    );
  }
}
