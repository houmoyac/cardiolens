import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/professional_title_field.dart';
import 'forgot_password_screen.dart';
import 'main_tab_screen.dart';

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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _professionalTitle;

  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _workplaceController.dispose();
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
        final workplace = _workplaceController.text.trim();
        await AuthService.instance.register(
          email: _emailController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          password: _passwordController.text,
          workplace: workplace.isEmpty ? null : workplace,
          professionalTitle: _professionalTitle,
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
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainTabScreen()));
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
                  Center(child: Image.asset('assets/logo_transparent.png', height: 64)),
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
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Prénom',
                        hintText: 'ex : Amina',
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Requis'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        hintText: 'ex : Belkacem',
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Requis'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _workplaceController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Cabinet médical / Hôpital (optionnel)',
                        hintText: 'ex : Cabinet Saint-Michel',
                      ),
                    ),
                    const SizedBox(height: 14),
                    ProfessionalTitleField(
                      initialValue: _professionalTitle,
                      onChanged: (value) => _professionalTitle = value,
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
                  if (!_isRegisterMode) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              ),
                        child: const Text('Mot de passe oublié ?', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  ],
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
