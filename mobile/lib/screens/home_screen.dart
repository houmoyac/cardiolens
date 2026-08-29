import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/sample_cases.dart';
import '../models/ecg_result.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'analyzing_screen.dart';
import 'results_screen.dart';
import 'scanning_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', height: 40),
            const SizedBox(width: 8),
            const Text('CardioLens'),
          ],
        ),
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
            subtitle: 'Fichier numérique (CSV)',
            filled: true,
            onTap: () => _pickRealFileAndAnalyze(context),
          ),
          const SizedBox(height: 10),
          _ImportButton(
            icon: Icons.camera_alt_outlined,
            title: 'Scanner via photo',
            subtitle: 'Tracé papier (aperçu du parcours)',
            filled: false,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ScanningScreen())),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Exemples',
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

  /// Picks a real CSV file from device storage, parses it client-side
  /// (tolerant of a header row / leading time column — see
  /// parseEcgSignalCsv), asks for the sampling rate + sex the backend
  /// needs, then sends it to the real analysis endpoint. No demo-data
  /// fallback here on purpose: there's no legitimate stand-in for a file
  /// the doctor actually brought in — see AnalyzingScreen.realImport.
  Future<void> _pickRealFileAndAnalyze(BuildContext context) async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
    } catch (_) {
      if (!context.mounted) return;
      _showImportError(context, "Impossible d'ouvrir le sélecteur de fichiers.");
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      if (!context.mounted) return;
      _showImportError(context, 'Impossible de lire ce fichier.');
      return;
    }

    final List<double> signal;
    try {
      signal = parseEcgSignalCsv(utf8.decode(bytes, allowMalformed: true));
    } on InvalidSignalFileException catch (e) {
      if (!context.mounted) return;
      _showImportError(context, e.message);
      return;
    }

    if (!context.mounted) return;
    final details = await _askImportDetails(context);
    if (details == null || !context.mounted) return;

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyzingScreen.realImport(
          import: RealEcgImport(
            patientLabel: details.patientLabel,
            dateLabel: 'Importé le ${_todayLabel()}',
            signal: signal,
            samplingRateHz: details.samplingRateHz,
            sex: details.sex,
          ),
        ),
      ),
    );
  }

  void _showImportError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_ImportDetails?> _askImportDetails(BuildContext context) {
    final patientController = TextEditingController();
    final samplingRateController = TextEditingController(text: '500');
    String? sex;

    return showDialog<_ImportDetails>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Détails du tracé'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: patientController,
                decoration: const InputDecoration(
                  labelText: 'Patient (optionnel)',
                  hintText: 'ex : Patient #A-3012',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: samplingRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Fréquence d'échantillonnage (Hz)",
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: sex,
                decoration: const InputDecoration(labelText: 'Sexe (optionnel)'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Non précisé')),
                  DropdownMenuItem(value: 'F', child: Text('Femme')),
                  DropdownMenuItem(value: 'M', child: Text('Homme')),
                ],
                onChanged: (value) => setState(() => sex = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final rate = int.tryParse(samplingRateController.text.trim());
                if (rate == null || rate <= 0) return;
                final patientLabel = patientController.text.trim();
                Navigator.of(dialogContext).pop(
                  _ImportDetails(
                    patientLabel: patientLabel.isEmpty ? 'ECG importé' : patientLabel,
                    samplingRateHz: rate,
                    sex: sex,
                  ),
                );
              },
              child: const Text('Analyser'),
            ),
          ],
        ),
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.day)}/${two(now.month)}/${now.year}';
  }

}

class _ImportDetails {
  const _ImportDetails({
    required this.patientLabel,
    required this.samplingRateHz,
    this.sex,
  });

  final String patientLabel;
  final int samplingRateHz;
  final String? sex;
}

class _ImportButton extends StatelessWidget {
  const _ImportButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : CardioLensColors.textPrimary;
    return Material(
      color: filled ? CardioLensColors.primary : CardioLensColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
