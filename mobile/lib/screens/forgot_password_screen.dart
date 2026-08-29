import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_config.dart';
import '../theme.dart';

/// Two steps on one screen: request a reset (email), then apply it (token
/// + new password). Honest about a real, current limitation: no email
/// provider is configured on the backend yet, so the reset token isn't
/// actually delivered anywhere — it's only visible in the backend's own
/// logs (see cardiolens.api.forgot_password). That's a dev-mode stand-in,
/// not a finished flow; said plainly here rather than pretending an email
/// was sent.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isRequesting = false;
  bool _isResetting = false;
  String? _requestError;
  String? _resetError;
  bool _requestSent = false;
  bool _resetDone = false;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _requestError = 'Email invalide');
      return;
    }
    setState(() {
      _isRequesting = true;
      _requestError = null;
    });
    try {
      await ApiClient(baseUrl: apiBaseUrl).forgotPassword(email);
      if (mounted) setState(() => _requestSent = true);
    } catch (e) {
      if (mounted) setState(() => _requestError = e.toString());
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _applyReset() async {
    if (_tokenController.text.trim().isEmpty || _newPasswordController.text.length < 8) {
      setState(() => _resetError = 'Code requis, mot de passe d\'au moins 8 caractères');
      return;
    }
    setState(() {
      _isResetting = true;
      _resetError = null;
    });
    try {
      await ApiClient(baseUrl: apiBaseUrl).resetPassword(
        token: _tokenController.text.trim(),
        newPassword: _newPasswordController.text,
      );
      if (mounted) setState(() => _resetDone = true);
    } catch (e) {
      if (mounted) setState(() => _resetError = e.toString());
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CardioLensColors.aiBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CardioLensColors.aiBorder),
            ),
            child: const Text(
              "L'envoi d'email n'est pas encore configuré sur ce serveur de "
              'développement. Le code de réinitialisation est écrit dans les '
              'journaux du serveur (pas envoyé par email) — demande-le à la '
              'personne qui gère le backend.',
              style: TextStyle(fontSize: 12, color: CardioLensColors.aiText),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '1. DEMANDER UN CODE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CardioLensColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_requestSent,
            decoration: const InputDecoration(labelText: 'Email du compte'),
          ),
          if (_requestError != null) ...[
            const SizedBox(height: 8),
            Text(
              _requestError!,
              style: const TextStyle(fontSize: 12.5, color: CardioLensColors.alertAccent),
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: (_isRequesting || _requestSent) ? null : _requestReset,
            child: _isRequesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : Text(_requestSent ? 'Code demandé' : 'Demander un code'),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            '2. RÉINITIALISER AVEC LE CODE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CardioLensColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tokenController,
            enabled: !_resetDone,
            decoration: const InputDecoration(labelText: 'Code reçu'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            enabled: !_resetDone,
            decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
          ),
          if (_resetError != null) ...[
            const SizedBox(height: 8),
            Text(
              _resetError!,
              style: const TextStyle(fontSize: 12.5, color: CardioLensColors.alertAccent),
            ),
          ],
          if (_resetDone) ...[
            const SizedBox(height: 8),
            const Text(
              'Mot de passe réinitialisé — tu peux te reconnecter.',
              style: TextStyle(fontSize: 12.5, color: CardioLensColors.okText),
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: (_isResetting || _resetDone) ? null : _applyReset,
            child: _isResetting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Text('Réinitialiser'),
          ),
          if (_resetDone) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour à la connexion'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
