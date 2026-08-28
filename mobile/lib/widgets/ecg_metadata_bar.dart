import 'package:flutter/material.dart';

import '../models/ecg_result.dart';
import '../theme.dart';

/// Shows where this ECG actually came from and how it was actually
/// processed — real pipeline facts (see EcgCase docs), never invented
/// clinical claims like a device model we don't know or a lead count we
/// don't record.
class EcgMetadataBar extends StatelessWidget {
  const EcgMetadataBar({super.key, required this.ecgCase});

  final EcgCase ecgCase;

  @override
  Widget build(BuildContext context) {
    final items = [
      ecgCase.sourceLabel,
      ecgCase.leadLabel,
      '${ecgCase.samplingRateHz} Hz',
      'Filtre secteur ${ecgCase.powerlineFilterHz} Hz',
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF2F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item,
              style: const TextStyle(
                fontSize: 11,
                color: CardioLensColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
