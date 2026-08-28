import 'package:flutter/material.dart';

import '../models/ecg_result.dart';
import '../theme.dart';
import '../widgets/ecg_trace_painter.dart';
import 'report_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.ecgCase});

  final EcgCase ecgCase;

  @override
  Widget build(BuildContext context) {
    final m = ecgCase.measurements;
    final qrsWarn = m.qrsDurationMs > 120;
    final qtcWarn = m.qtcBazettMs > 450;

    return Scaffold(
      appBar: AppBar(
        title: Text(ecgCase.patientLabel, style: const TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              child: Column(
                children: [
                  const EcgTracePainter(),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '25 mm/s · 10 mm/mV',
                      style: TextStyle(
                        fontSize: 11,
                        color: CardioLensColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: 'FC', value: '${m.heartRateBpm.round()} bpm'),
              _Chip(label: 'PR', value: '${m.prIntervalMs.round()} ms'),
              _Chip(
                label: 'QRS',
                value: '${m.qrsDurationMs.round()} ms',
                warn: qrsWarn,
              ),
              _Chip(
                label: 'QTc (Bazett)',
                value: '${m.qtcBazettMs.round()} ms',
                warn: qtcWarn,
              ),
              _Chip(
                label: 'QTc (Fridericia)',
                value: '${m.qtcFridericiaMs.round()} ms',
              ),
              _Chip(
                label: 'Variabilité RR',
                value: '${m.rrVariabilityPct.toStringAsFixed(1)}%',
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel(
            badgeText: 'RÈGLE',
            badgeColor: CardioLensColors.ruleBadgeBg,
            title: 'Alertes cliniques — mesures directes',
          ),
          const SizedBox(height: 8),
          for (final alert in ecgCase.ruleAlerts) _AlertCard(alert: alert),
          const SizedBox(height: 22),
          const _SectionLabel(
            badgeText: 'IA',
            badgeColor: CardioLensColors.aiAccent,
            title: 'Détection algorithmique',
          ),
          const SizedBox(height: 8),
          if (ecgCase.aiAlerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3F1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDE6E1)),
              ),
              child: const Text(
                "Aucun modèle IA branché pour l'instant — cette section "
                'apparaîtra une fois le composant de détection (phase 2) ajouté.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF3A5647),
                  height: 1.4,
                ),
              ),
            )
          else
            for (final alert in ecgCase.aiAlerts) _AlertCard(alert: alert),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showTodoSnack(context, 'Validation'),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Valider'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showTodoSnack(context, 'Correction'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Corriger'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ReportScreen(ecgCase: ecgCase)),
            ),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Générer le compte-rendu PDF'),
          ),
        ],
      ),
    );
  }

  void _showTodoSnack(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action — pas encore branché à un vrai backend.'),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value, this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: warn ? CardioLensColors.alertBg : CardioLensColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: warn ? CardioLensColors.alertBorder : CardioLensColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: warn
                  ? CardioLensColors.alertAccent
                  : CardioLensColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: warn
                  ? CardioLensColors.alertAccent
                  : CardioLensColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.badgeText,
    required this.badgeColor,
    required this.title,
  });

  final String badgeText;
  final Color badgeColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            badgeText,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final ClinicalAlert alert;

  @override
  Widget build(BuildContext context) {
    final warn = alert.severity == AlertSeverity.warning;
    final bg = warn ? CardioLensColors.alertBg : const Color(0xFFF0F3F1);
    final border = warn
        ? CardioLensColors.alertBorder
        : const Color(0xFFDDE6E1);
    final accent = warn
        ? CardioLensColors.alertAccent
        : const Color(0xFF6B8E7C);
    final text = warn ? CardioLensColors.alertText : const Color(0xFF3A5647);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 32, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alert.message,
              style: TextStyle(fontSize: 13, color: text, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
