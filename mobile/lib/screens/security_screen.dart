import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isChangingPassword = false;
  String? _passwordError;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isChangingPassword = true;
      _passwordError = null;
    });
    try {
      await AuthService.instance.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mot de passe changé.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _passwordError = e.toString());
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sécurité & confidentialité', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'MOT DE PASSE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CardioLensColors.textMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                      validator: (value) => (value == null || value.length < 8)
                          ? 'Au moins 8 caractères'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le nouveau mot de passe',
                      ),
                      validator: (value) => value != _newPasswordController.text
                          ? 'Les mots de passe ne correspondent pas'
                          : null,
                    ),
                    if (_passwordError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _passwordError!,
                        style: const TextStyle(
                          color: CardioLensColors.alertAccent,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _isChangingPassword ? null : _changePassword,
                      child: _isChangingPassword
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Changer le mot de passe'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
