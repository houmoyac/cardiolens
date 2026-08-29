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

  String _initials(String? firstName, String? lastName) {
    final f = (firstName?.isNotEmpty ?? false) ? firstName![0] : '';
    final l = (lastName?.isNotEmpty ?? false) ? lastName![0] : '';
    final initials = '$f$l'.toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  @override
  Widget build(BuildContext context) {
    final doctor = AuthService.instance.currentUser;
    final logoUrl = AuthService.instance.logoUrl;

    return Scaffold(
      backgroundColor: CardioLensColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: CardioLensColors.primary,
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [CardioLensColors.primaryDark, CardioLensColors.primary],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(doctor?.firstName, doctor?.lastName),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        doctor?.displayName ?? '',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doctor?.email ?? '',
                        style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionCard(
                  icon: Icons.local_hospital_outlined,
                  title: 'Cabinet / hôpital',
                  subtitle: 'Affiché en en-tête des comptes-rendus.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _workplaceController,
                        decoration: const InputDecoration(
                          hintText: 'ex : Cabinet Saint-Michel',
                          prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PrimaryActionButton(
                        label: 'Enregistrer',
                        isLoading: _isSavingWorkplace,
                        onPressed: _saveWorkplace,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.image_outlined,
                  title: 'Logo du cabinet / hôpital',
                  child: Column(
                    children: [
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: CardioLensColors.background,
                                border: Border.all(
                                  color: CardioLensColors.border,
                                  width: logoUrl == null ? 1.4 : 1,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: logoUrl == null
                                  ? const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: CardioLensColors.textMuted,
                                      size: 30,
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(19),
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
                            if (logoUrl != null)
                              Positioned(
                                right: -6,
                                bottom: -6,
                                child: _CircleIconButton(
                                  icon: Icons.delete_outline,
                                  color: CardioLensColors.alertAccent,
                                  background: CardioLensColors.alertBg,
                                  onPressed: _isUploadingLogo ? null : _removeLogo,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PrimaryActionButton(
                        label: logoUrl == null ? 'Importer un logo' : 'Changer le logo',
                        icon: Icons.upload_outlined,
                        isLoading: _isUploadingLogo,
                        outlined: true,
                        onPressed: _pickAndUploadLogo,
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: CardioLensColors.alertAccent, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.lock_outline,
                  title: 'Mot de passe',
                  child: Form(
                    key: _passwordFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe actuel',
                            prefixIcon: Icon(Icons.lock_open_outlined, size: 20),
                          ),
                          validator: (value) =>
                              (value == null || value.isEmpty) ? 'Requis' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Nouveau mot de passe',
                            prefixIcon: Icon(Icons.key_outlined, size: 20),
                          ),
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
                            prefixIcon: Icon(Icons.check_circle_outline, size: 20),
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
                        _PrimaryActionButton(
                          label: 'Changer le mot de passe',
                          isLoading: _isChangingPassword,
                          onPressed: _changePassword,
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: CardioLensColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 17, color: CardioLensColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: CardioLensColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final bool isLoading;
  final bool outlined;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: outlined ? CardioLensColors.primary : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 8)],
              Text(label),
            ],
          );

    return outlined
        ? OutlinedButton(onPressed: isLoading ? null : onPressed, child: child)
        : ElevatedButton(onPressed: isLoading ? null : onPressed, child: child);
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 1.5,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
