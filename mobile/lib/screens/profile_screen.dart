import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ecg_result.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'about_screen.dart';
import 'analysis_history_screen.dart';
import 'login_screen.dart';
import 'personal_info_screen.dart';
import 'professional_info_screen.dart';
import 'security_screen.dart';

/// A hub, not a form: identity (photo, name, title, workplace) and real
/// activity stats up top, then a list menu into focused sub-screens. Used
/// to be one long scrolling form — split up once it grew past three
/// sections, matching how a settings hub usually looks in a real app.
///
/// Deliberately does NOT include: a notifications bell/badge (no
/// notification system exists — a fake badge count would be a lie), or a
/// "verified" checkmark next to the doctor's name (no identity
/// verification exists — showing one on a medical professional's profile
/// would be actively misleading, not just an empty affordance).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingAvatar = false;
  String? _error;

  late final Future<List<EcgCase>> _casesFuture = _loadCases();

  Future<List<EcgCase>> _loadCases() {
    final token = AuthService.instance.token;
    return token == null
        ? Future.value(const [])
        : ApiClient(baseUrl: apiBaseUrl).fetchCases(token);
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

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctor = AuthService.instance.currentUser;
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
                        if ((doctor?.workplace ?? '').isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            doctor!.workplace!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CardioLensColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: CardioLensColors.alertAccent, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 14),
          FutureBuilder<List<EcgCase>>(
            future: _casesFuture,
            builder: (context, snapshot) {
              final cases = snapshot.data;
              if (cases == null) return const SizedBox.shrink();
              final now = DateTime.now();
              final thisWeek = cases
                  .where((c) => c.createdAt != null && now.difference(c.createdAt!).inDays < 7)
                  .length;
              final withoutAlert = cases.where((c) => !c.hasWarning).length;
              final normalPct = cases.isEmpty ? null : (withoutAlert / cases.length * 100).round();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(child: _StatItem(value: '${cases.length}', label: 'ECG analysés')),
                      const _StatDivider(),
                      Expanded(child: _StatItem(value: '$thisWeek', label: 'Cette semaine')),
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
          Card(
            child: Column(
              children: [
                _MenuRow(
                  icon: Icons.person_outline,
                  title: 'Informations personnelles',
                  subtitle: 'Nom, prénom, email',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const PersonalInfoScreen())),
                ),
                const _MenuDivider(),
                _MenuRow(
                  icon: Icons.medical_information_outlined,
                  title: 'Informations professionnelles',
                  subtitle: 'Profession, cabinet, logo',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ProfessionalInfoScreen())),
                ),
                const _MenuDivider(),
                _MenuRow(
                  icon: Icons.lock_outline,
                  title: 'Sécurité & confidentialité',
                  subtitle: 'Mot de passe',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const SecurityScreen())),
                ),
                const _MenuDivider(),
                _MenuRow(
                  icon: Icons.history,
                  title: 'Historique des analyses',
                  subtitle: 'Consulter tes analyses',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AnalysisHistoryScreen())),
                ),
                const _MenuDivider(),
                _MenuRow(
                  icon: Icons.info_outline,
                  title: 'À propos de CardioLens',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _logout(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: CardioLensColors.alertAccent),
                    SizedBox(width: 12),
                    Text(
                      'Se déconnecter',
                      style: TextStyle(
                        color: CardioLensColors.alertAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: CardioLensColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: CardioLensColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: CardioLensColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: CardioLensColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 64),
      child: Divider(height: 1, color: CardioLensColors.border),
    );
  }
}
