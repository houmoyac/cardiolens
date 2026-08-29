import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';

/// Editing name here calls the same PATCH /auth/me as the professional-info
/// screen — the backend requires first_name/last_name on every update (see
/// UserProfileUpdate), so this always resends the doctor's current
/// workplace/title alongside whatever name change was made, never blanking
/// them out.
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  late final TextEditingController _firstNameController = TextEditingController(
    text: AuthService.instance.currentUser?.firstName ?? '',
  );
  late final TextEditingController _lastNameController = TextEditingController(
    text: AuthService.instance.currentUser?.lastName ?? '',
  );

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Prénom et nom requis.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final doctor = AuthService.instance.currentUser;
      await AuthService.instance.updateProfile(
        firstName: firstName,
        lastName: lastName,
        workplace: doctor?.workplace,
        professionalTitle: doctor?.professionalTitle,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informations mises à jour.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = AuthService.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informations personnelles', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lastNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nom'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: doctor?.email ?? ''),
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      helperText: "L'email ne peut pas être modifié ici.",
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: CardioLensColors.alertAccent,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
