/// Mirrors cardiolens.models on the backend — kept in sync by hand for now
/// (see ARCHITECTURE.md on the backend repo for why measurements are
/// explicitly source-tagged as rule vs AI, and never silently merged).
enum AlertSource { rule, ai }

enum AlertSeverity { info, warning }

class ClinicalAlert {
  const ClinicalAlert({
    required this.code,
    required this.message,
    required this.source,
    required this.severity,
    this.confidence,
  });

  final String code;
  final String message;
  final AlertSource source;
  final AlertSeverity severity;

  /// Set only for AI-sourced alerts (0-1) — rule alerts are never scored.
  final double? confidence;
}

class EcgMeasurements {
  const EcgMeasurements({
    required this.heartRateBpm,
    required this.prIntervalMs,
    required this.qrsDurationMs,
    required this.qtcBazettMs,
    required this.qtcFridericiaMs,
    required this.rrVariabilityPct,
  });

  final double heartRateBpm;
  final double prIntervalMs;
  final double qrsDurationMs;
  final double qtcBazettMs;
  final double qtcFridericiaMs;
  final double rrVariabilityPct;
}

/// One analyzed ECG: measurements + alerts, as returned by the backend's
/// /analyze endpoint (see lib/services/api_client.dart) — or, as a fallback
/// when the backend isn't reachable, the bundled static values in
/// lib/data/sample_cases.dart.
class EcgCase {
  const EcgCase({
    required this.id,
    required this.patientLabel,
    required this.dateLabel,
    required this.measurements,
    required this.alerts,
    this.signalAssetPath,
    this.sourceLabel = 'PTB-XL (dataset public)',
    this.leadLabel = 'Dérivation DII',
    this.samplingRateHz = 500,
    this.powerlineFilterHz = 50,
  });

  final String id;
  final String patientLabel;
  final String dateLabel;
  final EcgMeasurements measurements;
  final List<ClinicalAlert> alerts;

  /// Path to the bundled raw signal for this case (assets/sample_ecgs/...),
  /// sent to the real backend when it's reachable. Null for a case that
  /// only ever has static fallback measurements.
  final String? signalAssetPath;

  /// Provenance shown to the physician so they know what they're looking
  /// at — never invented per-case, just the real, current pipeline
  /// defaults (single lead, 500 Hz, NeuroKit2's default 50 Hz mains-hum
  /// filter — see backend ARCHITECTURE.md on why it's mono-lead for now).
  final String sourceLabel;
  final String leadLabel;
  final int samplingRateHz;
  final int powerlineFilterHz;

  bool get hasWarning => alerts.any((a) => a.severity == AlertSeverity.warning);

  List<ClinicalAlert> get ruleAlerts =>
      alerts.where((a) => a.source == AlertSource.rule).toList();

  List<ClinicalAlert> get aiAlerts =>
      alerts.where((a) => a.source == AlertSource.ai).toList();
}
