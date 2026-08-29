import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ecg_result.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/professional_title_field.dart';

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
  String? _professionalTitle = AuthService.instance.currentUser?.professionalTitle;

  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSavingInfo = false;
  bool _isUploadingLogo = false;
  bool _isUploadingAvatar = false;
  bool _isChangingPassword = false;
  String? _error;
  String? _passwordError;

  late final Future<List<EcgCase>> _casesFuture = _loadCases();

  @override
  void dispose() {
    _workplaceController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<List<EcgCase>> _loadCases() {
    final token = AuthService.instance.token;
    return token == null
        ? Future.value(const [])
        : ApiClient(baseUrl: apiBaseUrl).fetchCases(token);
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

  Future<void> _saveProfessionalInfo() async {
    setState(() {
      _isSavingInfo = true;
      _error = null;
    });
    try {
      final trimmed = _workplaceController.text.trim();
      await AuthService.instance.updateProfile(
        workplace: trimmed.isEmpty ? null : trimmed,
        professionalTitle: _professionalTitle,
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informations mises à jour.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSavingInfo = false);
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

  Future<void> _pickAndUploadAvatar() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    setState(() {
      _isUploadingAvatar = true;
      _error = null;
    });
    try {
      final bytes = await picked.readAsBytes();
      await AuthService.instance.uploadAvatar(bytes);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() {
      _isUploadingAvatar = true;
      _error = null;
    });
    try {
      await AuthService.instance.deleteAvatar();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _showAvatarOptions(BuildContext context, {required bool hasAvatar}) async {
    final action = await showModalBottomSheet<_AvatarAction>(
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
              leading: const Icon(Icons.photo_outlined),
              title: Text(hasAvatar ? 'Changer la photo' : 'Ajouter une photo'),
              onTap: () => Navigator.of(sheetContext).pop(_AvatarAction.pick),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: CardioLensColors.alertAccent),
                title: const Text(
                  'Supprimer la photo',
                  style: TextStyle(color: CardioLensColors.alertAccent),
                ),
                onTap: () => Navigator.of(sheetContext).pop(_AvatarAction.remove),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == _AvatarAction.pick) {
      await _pickAndUploadAvatar();
    } else if (action == _AvatarAction.remove) {
      await _removeAvatar();
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
    final avatarUrl = AuthService.instance.avatarUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil', style: TextStyle(fontSize: 15))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _isUploadingAvatar
                        ? null
                        : () => _showAvatarOptions(context, hasAvatar: avatarUrl != null),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CardioLensColors.primary.withValues(alpha: 0.08),
                          ),
                          alignment: Alignment.center,
                          child: avatarUrl == null
                              ? Text(
                                  _initials(doctor?.firstName, doctor?.lastName),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: CardioLensColors.primary,
                                  ),
                                )
                              : ClipOval(
                                  child: Image.network(
                                    avatarUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    headers: AuthService.instance.authHeaders,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.person_outline,
                                      color: CardioLensColors.textMuted,
                                    ),
                                  ),
                                ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: CardioLensColors.primary,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: _isUploadingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(3),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.6,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor?.displayName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        if ((doctor?.professionalTitle ?? '').isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            doctor!.professionalTitle!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CardioLensColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          doctor?.email ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: CardioLensColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<EcgCase>>(
            future: _casesFuture,
            builder: (context, snapshot) {
              final cases = snapshot.data;
              if (cases == null) return const SizedBox.shrink();
              final now = DateTime.now();
              final thisWeek = cases
                  .where(
                    (c) => c.createdAt != null && now.difference(c.createdAt!).inDays < 7,
                  )
                  .length;
              final withoutAlert = cases.where((c) => !c.hasWarning).length;
              final normalPct = cases.isEmpty
                  ? null
                  : (withoutAlert / cases.length * 100).round();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatItem(value: '${cases.length}', label: 'ECG analysés'),
                      ),
                      const _StatDivider(),
                      Expanded(
                        child: _StatItem(value: '$thisWeek', label: 'Cette semaine'),
                      ),
                      const _StatDivider(),
                      Expanded(
                        child: _StatItem(
                          value: normalPct == null ? '—' : '$normalPct%',
                          label: 'Sans anomalie',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Informations professionnelles',
            subtitle: 'Affichées en en-tête et en pied des comptes-rendus.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfessionalTitleField(
                  initialValue: _professionalTitle,
                  onChanged: (value) => _professionalTitle = value,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _workplaceController,
                  decoration: const InputDecoration(
                    labelText: 'Cabinet / hôpital (optionnel)',
                    hintText: 'ex : Cabinet Saint-Michel',
                  ),
                ),
                const SizedBox(height: 12),
                _PrimaryActionButton(
                  label: 'Enregistrer',
                  isLoading: _isSavingInfo,
                  onPressed: _saveProfessionalInfo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Logo du cabinet / hôpital',
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: CardioLensColors.background,
                    border: Border.all(color: CardioLensColors.border),
                  ),
                  child: logoUrl == null
                      ? const Icon(
                          Icons.image_outlined,
                          color: CardioLensColors.textMuted,
                          size: 22,
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PrimaryActionButton(
                        label: logoUrl == null ? 'Importer' : 'Changer',
                        isLoading: _isUploadingLogo,
                        outlined: true,
                        compact: true,
                        onPressed: _pickAndUploadLogo,
                      ),
                      if (logoUrl != null) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _isUploadingLogo ? null : _removeLogo,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: CardioLensColors.alertAccent,
                          ),
                          child: const Text('Supprimer', style: TextStyle(fontSize: 12.5)),
                        ),
                      ],
                    ],
                  ),
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
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Mot de passe',
            child: Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
                    validator: (value) => (value == null || value.isEmpty) ? 'Requis' : null,
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
                  _PrimaryActionButton(
                    label: 'Changer le mot de passe',
                    isLoading: _isChangingPassword,
                    onPressed: _changePassword,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});

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
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: CardioLensColors.textMuted,
                letterSpacing: 0.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: CardioLensColors.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
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
    this.outlined = false,
    this.compact = false,
  });

  final String label;
  final bool isLoading;
  final bool outlined;
  final bool compact;
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
        : Text(label);

    final style = compact
        ? OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: const Size(0, 34),
            textStyle: const TextStyle(fontSize: 12.5),
          )
        : null;

    return outlined
        ? OutlinedButton(onPressed: isLoading ? null : onPressed, style: style, child: child)
        : ElevatedButton(onPressed: isLoading ? null : onPressed, style: style, child: child);
  }
}

enum _AvatarAction { pick, remove }

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: CardioLensColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: CardioLensColors.textSecondary),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: CardioLensColors.border);
  }
}
