import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'home_screen.dart';

/// First screen when no session is stored — toggles between "Se connecter"
/// and "Créer un compte". One doctor, one phone, one account: this is
/// where that identity is created or resumed, and it's what makes the
/// report's "Validé par" field mean something instead of a free-text
/// placeholder.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      if (_isRegisterMode) {
        await AuthService.instance.register(
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await AuthService.instance.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Image.asset('assets/logo.png', height: 64)),
                  const SizedBox(height: 12),
                  const Text(
                    'CardioLens',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: CardioLensColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRegisterMode
                        ? 'Créez votre compte médecin'
                        : 'Connectez-vous à votre compte',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CardioLensColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_isRegisterMode) ...[
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        hintText: 'ex : Dr. Amina Belkacem',
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Requis'
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => (value == null || !value.contains('@'))
                        ? 'Email invalide'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mot de passe'),
                    validator: (value) => (value == null || value.length < 8)
                        ? 'Au moins 8 caractères'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: CardioLensColors.alertAccent,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isRegisterMode ? 'Créer mon compte' : 'Se connecter'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() {
                            _isRegisterMode = !_isRegisterMode;
                            _error = null;
                          }),
                    child: Text(
                      _isRegisterMode
                          ? "J'ai déjà un compte"
                          : "Pas encore de compte ? En créer un",
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
