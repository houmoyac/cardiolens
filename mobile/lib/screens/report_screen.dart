import 'package:flutter/material.dart';

import '../models/ecg_result.dart';
import '../theme.dart';
import '../widgets/ecg_metadata_bar.dart';
import '../widgets/ecg_trace_painter.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, required this.ecgCase});

  final EcgCase ecgCase;

  @override
  Widget build(BuildContext context) {
    final m = ecgCase.measurements;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compte-rendu', style: TextStyle(fontSize: 15)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: CardioLensColors.okBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Non validé',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CardioLensColors.okText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/logo.png', height: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'CardioLens',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '[Cabinet médical]',
                        style: TextStyle(
                          fontSize: 11,
                          color: CardioLensColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  const Text(
                    'PATIENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CardioLensColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ecgCase.patientLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    ecgCase.dateLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CardioLensColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  EcgMetadataBar(ecgCase: ecgCase),
                  const SizedBox(height: 16),
                  const EcgTracePainter(height: 70),
                  const Divider(height: 28),
                  const Text(
                    'MESURES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CardioLensColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ReportRow('FC', '${m.heartRateBpm.round()} bpm'),
                  _ReportRow('PR', '${m.prIntervalMs.round()} ms'),
                  _ReportRow(
                    'QRS',
                    '${m.qrsDurationMs.round()} ms',
                    warn: m.qrsDurationMs > 120,
                  ),
                  _ReportRow(
                    'QTc (Bazett)',
                    '${m.qtcBazettMs.round()} ms',
                    warn: m.qtcBazettMs > 450,
                  ),
                  _ReportRow(
                    'QTc (Fridericia)',
                    '${m.qtcFridericiaMs.round()} ms',
                  ),
                  const Divider(height: 28),
                  const Text(
                    'INTERPRÉTATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CardioLensColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ecgCase.ruleAlerts.map((a) => a.message).join('. '),
                    style: const TextStyle(fontSize: 13, height: 1.55),
                  ),
                  const Divider(height: 28),
                  const Text(
                    'VALIDÉ PAR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CardioLensColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '[Dr. Nom Prénom] — en attente de validation',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showTodoSnack(context),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Télécharger PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showTodoSnack(context),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Partager'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTodoSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Export PDF pas encore implémenté.")),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(this.label, this.value, {this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: warn
                  ? CardioLensColors.alertAccent
                  : CardioLensColors.textSecondary,
              fontWeight: warn ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
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
