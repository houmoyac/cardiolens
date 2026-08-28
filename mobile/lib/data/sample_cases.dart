import '../models/ecg_result.dart';

/// Bundled sample cases — the same 3 real, anonymized PTB-XL recordings
/// already validated through the rules engine and the web test tool
/// (see backend/src/cardiolens/sample_ecgs/). The measurements/alerts here
/// are the last known-good values from the backend, used as a fallback
/// display and for the read-only "Analyses récentes" list; when a case is
/// picked to actually analyze (see ScanningScreen/AnalyzingScreen), its
/// signalAssetPath is sent to the real backend and the real response is
/// used instead.
final sampleCases = <EcgCase>[
  const EcgCase(
    id: 'ptbxl-1',
    patientLabel: 'Patient #A-2288',
    dateLabel: 'Hier, 16:05',
    signalAssetPath: 'assets/sample_ecgs/sample_normal_ecg.csv',
    measurements: EcgMeasurements(
      heartRateBpm: 64,
      prIntervalMs: 134,
      qrsDurationMs: 118,
      qtcBazettMs: 410,
      qtcFridericiaMs: 405,
      rrVariabilityPct: 1.8,
    ),
    alerts: [
      ClinicalAlert(
        code: 'within_normal_limits',
        message: 'Fréquence, PR, QRS, QTc et axe dans les normes',
        source: AlertSource.rule,
        severity: AlertSeverity.info,
      ),
    ],
  ),
  const EcgCase(
    id: 'ptbxl-2',
    patientLabel: 'Patient #A-2291',
    dateLabel: "Aujourd'hui, 09:42",
    signalAssetPath: 'assets/sample_ecgs/sample_bradycardia_ecg.csv',
    measurements: EcgMeasurements(
      heartRateBpm: 48,
      prIntervalMs: 166,
      qrsDurationMs: 108,
      qtcBazettMs: 344,
      qtcFridericiaMs: 358,
      rrVariabilityPct: 6.2,
    ),
    alerts: [
      ClinicalAlert(
        code: 'bradycardia',
        message: 'Bradycardie (48 bpm, seuil < 60 bpm)',
        source: AlertSource.rule,
        severity: AlertSeverity.warning,
      ),
    ],
  ),
  const EcgCase(
    id: 'ptbxl-3017',
    patientLabel: 'Patient #A-2279',
    dateLabel: 'Lun. 24, 11:18',
    signalAssetPath: 'assets/sample_ecgs/sample_pr_long_ecg.csv',
    measurements: EcgMeasurements(
      heartRateBpm: 61,
      prIntervalMs: 180,
      qrsDurationMs: 171,
      qtcBazettMs: 420,
      qtcFridericiaMs: 419,
      rrVariabilityPct: 1.6,
    ),
    alerts: [
      ClinicalAlert(
        code: 'qrs_wide',
        message: 'QRS élargi (171 ms), évoquant un bloc de branche',
        source: AlertSource.rule,
        severity: AlertSeverity.warning,
      ),
    ],
  ),
];
