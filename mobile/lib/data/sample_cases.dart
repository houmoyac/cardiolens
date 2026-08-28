import '../models/ecg_result.dart';

/// Bundled sample cases — the same 3 real, anonymized PTB-XL recordings
/// already validated through the rules engine and the web test tool
/// (see backend/src/cardiolens/sample_ecgs/). Values here are the actual
/// measured output, not invented numbers, so this screen shows something
/// real while the app isn't wired to a live backend yet.
final sampleCases = <EcgCase>[
  const EcgCase(
    id: 'ptbxl-1',
    patientLabel: 'Patient #A-2288',
    dateLabel: 'Hier, 16:05',
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
