import 'package:flutter/material.dart';

import '../data/professional_titles.dart';

/// A preset dropdown (Médecin stagiaire, Assistant, Professeur, ...) with
/// an "Autre" option that reveals a free-text field — used on both the
/// registration form and the profile screen so the two stay identical.
class ProfessionalTitleField extends StatefulWidget {
  const ProfessionalTitleField({super.key, required this.initialValue, required this.onChanged});

  final String? initialValue;
  final ValueChanged<String?> onChanged;

  @override
  State<ProfessionalTitleField> createState() => _ProfessionalTitleFieldState();
}

class _ProfessionalTitleFieldState extends State<ProfessionalTitleField> {
  String? _selected;
  late final TextEditingController _otherController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    if (initial != null && professionalTitlePresets.contains(initial)) {
      _selected = initial;
      _otherController = TextEditingController();
    } else if (initial != null && initial.isNotEmpty) {
      _selected = professionalTitleOtherValue;
      _otherController = TextEditingController(text: initial);
    } else {
      _selected = null;
      _otherController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _emit() {
    if (_selected == professionalTitleOtherValue) {
      final text = _otherController.text.trim();
      widget.onChanged(text.isEmpty ? null : text);
    } else {
      widget.onChanged(_selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _selected,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Profession / titre (optionnel)',
            prefixIcon: Icon(Icons.badge_outlined, size: 20),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Non précisé')),
            for (final preset in professionalTitlePresets)
              DropdownMenuItem(value: preset, child: Text(preset)),
            const DropdownMenuItem(value: professionalTitleOtherValue, child: Text('Autre…')),
          ],
          onChanged: (value) {
            setState(() => _selected = value);
            _emit();
          },
        ),
        if (_selected == professionalTitleOtherValue) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otherController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Préciser…'),
            onChanged: (_) => _emit(),
          ),
        ],
      ],
    );
  }
}
