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

/// One analyzed ECG: measurements + alerts, as returned by (eventually) the
/// backend's /analyze endpoint. Today this is populated from bundled sample
/// data — see lib/data/sample_cases.dart — not a live API call.
class EcgCase {
  const EcgCase({
    required this.id,
    required this.patientLabel,
    required this.dateLabel,
    required this.measurements,
    required this.alerts,
  });

  final String id;
  final String patientLabel;
  final String dateLabel;
  final EcgMeasurements measurements;
  final List<ClinicalAlert> alerts;

  bool get hasWarning => alerts.any((a) => a.severity == AlertSeverity.warning);

  List<ClinicalAlert> get ruleAlerts =>
      alerts.where((a) => a.source == AlertSource.rule).toList();

  List<ClinicalAlert> get aiAlerts =>
      alerts.where((a) => a.source == AlertSource.ai).toList();
}
