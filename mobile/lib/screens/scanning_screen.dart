import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/sample_cases.dart';
import '../theme.dart';
import 'results_screen.dart';

/// The "Scanner via photo" flow. Honest about what it actually does today:
/// takes/picks a photo and shows the *intended* detection pipeline steps,
/// but there is no real image digitization behind it yet (that's a
/// separate, much bigger computer-vision project — see
/// backend/src/cardiolens/image_digitization.py for where that work is
/// starting). Landing on a bundled demo case here is a stand-in, exactly
/// like the CSV "Importer un ECG" flow, not a working scanner.
class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  File? _photo;
  int _stepIndex = 0;

  static const _steps = [
    'Document ECG détecté',
    'Correction de la perspective',
    'Amélioration du contraste',
    'Détection des dérivations',
    'Lecture du tracé',
  ];

  @override
  void initState() {
    super.initState();
    _pickPhoto();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? picked = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: CardioLensColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: CardioLensColors.primary,
              ),
              title: const Text('Prendre une photo'),
              onTap: () async {
                final file = await picker.pickImage(
                  source: ImageSource.camera,
                );
                if (sheetContext.mounted) Navigator.of(sheetContext).pop(file);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: CardioLensColors.primary,
              ),
              title: const Text('Choisir une photo'),
              onTap: () async {
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (sheetContext.mounted) Navigator.of(sheetContext).pop(file);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (mounted) setState(() => _photo = File(picked.path));
    await _runFakeDetectionSteps();
  }

  Future<void> _runFakeDetectionSteps() async {
    for (var i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _stepIndex = i + 1);
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // No real digitization pipeline exists yet — land on a demo case
    // rather than pretend this photo was actually analyzed.
    final demoCase = sampleCases.first;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultsScreen(ecgCase: demoCase)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un ECG')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_photo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_photo!, height: 160, fit: BoxFit.cover),
                ),
              const SizedBox(height: 20),
              const Text(
                'Analyse du document…',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _steps.length; i++)
                _StepRow(label: _steps[i], done: i < _stepIndex),
              const SizedBox(height: 20),
              const _DemoNotice(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            size: 17,
            color: done ? CardioLensColors.okText : CardioLensColors.textMuted,
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: done
                  ? CardioLensColors.textPrimary
                  : CardioLensColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: CardioLensColors.alertBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CardioLensColors.alertBorder),
      ),
      child: const Text(
        "L'extraction du tracé depuis une photo n'est pas encore "
        'implémentée — ce parcours affiche un cas de démonstration, '
        'pas une vraie analyse de ta photo.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, color: CardioLensColors.alertText),
      ),
    );
  }
}
