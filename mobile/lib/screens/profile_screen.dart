import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../theme.dart';

/// Reached from the account menu on the home screen. Where the doctor sets
/// what the report header actually shows for "[Cabinet médical]" and the
/// workplace logo — both used to be hardcoded placeholders (see
/// ReportScreen), the same gap "Validé par" had before authentication
/// existed at all.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _workplaceController = TextEditingController(
    text: AuthService.instance.currentUser?.workplace ?? '',
  );
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSavingWorkplace = false;
  bool _isUploadingLogo = false;
  bool _isChangingPassword = false;
  String? _error;
  String? _passwordError;

  @override
  void dispose() {
    _workplaceController.dispose();
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

  Future<void> _saveWorkplace() async {
    setState(() {
      _isSavingWorkplace = true;
      _error = null;
    });
    try {
      final trimmed = _workplaceController.text.trim();
      await AuthService.instance.updateWorkplace(trimmed.isEmpty ? null : trimmed);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cabinet / hôpital mis à jour.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSavingWorkplace = false);
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    setState(() {
      _isUploadingLogo = true;
      _error = null;
    });
    try {
      final bytes = await picked.readAsBytes();
      await AuthService.instance.uploadLogo(bytes);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _removeLogo() async {
    setState(() {
      _isUploadingLogo = true;
      _error = null;
    });
    try {
      await AuthService.instance.deleteLogo();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = AuthService.instance.currentUser;
    final logoUrl = AuthService.instance.logoUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor?.displayName ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doctor?.email ?? '',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: CardioLensColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CABINET / HÔPITAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CardioLensColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Affiché en en-tête des comptes-rendus.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CardioLensColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _workplaceController,
                    decoration: const InputDecoration(
                      hintText: 'ex : Cabinet Saint-Michel',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _isSavingWorkplace ? null : _saveWorkplace,
                      child: _isSavingWorkplace
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
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LOGO DU CABINET / HÔPITAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CardioLensColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        border: Border.all(color: CardioLensColors.border),
                        borderRadius: BorderRadius.circular(10),
                        color: CardioLensColors.background,
                      ),
                      child: logoUrl == null
                          ? const Icon(
                              Icons.image_outlined,
                              color: CardioLensColors.textMuted,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.network(
                                logoUrl,
                                headers: AuthService.instance.authHeaders,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: CardioLensColors.textMuted,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                          child: Text(logoUrl == null ? 'Importer un logo' : 'Changer le logo'),
                        ),
                      ),
                      if (logoUrl != null) ...[
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: _isUploadingLogo ? null : _removeLogo,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: CardioLensColors.alertAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(color: CardioLensColors.alertAccent, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MOT DE PASSE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CardioLensColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
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
