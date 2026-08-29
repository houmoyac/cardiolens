import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/professional_title_field.dart';

/// Profession/titre, cabinet/hôpital, and the workplace logo — everything
/// that ends up on the report header/footer (see ReportScreen), grouped
/// together since they're saved via the same PATCH /auth/me plus the
/// separate logo endpoints.
class ProfessionalInfoScreen extends StatefulWidget {
  const ProfessionalInfoScreen({super.key});

  @override
  State<ProfessionalInfoScreen> createState() => _ProfessionalInfoScreenState();
}

class _ProfessionalInfoScreenState extends State<ProfessionalInfoScreen> {
  late final TextEditingController _workplaceController = TextEditingController(
    text: AuthService.instance.currentUser?.workplace ?? '',
  );
  String? _professionalTitle = AuthService.instance.currentUser?.professionalTitle;

  bool _isSavingInfo = false;
  bool _isUploadingLogo = false;
  String? _error;

  @override
  void dispose() {
    _workplaceController.dispose();
    super.dispose();
  }

  Future<void> _saveProfessionalInfo() async {
    setState(() {
      _isSavingInfo = true;
      _error = null;
    });
    try {
      final doctor = AuthService.instance.currentUser;
      final trimmed = _workplaceController.text.trim();
      await AuthService.instance.updateProfile(
        firstName: doctor?.firstName ?? '',
        lastName: doctor?.lastName ?? '',
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

  @override
  Widget build(BuildContext context) {
    final logoUrl = AuthService.instance.logoUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informations professionnelles', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _SectionCard(
            title: 'Profession et cabinet',
            subtitle: 'Affichés en en-tête et en pied des comptes-rendus.',
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
                ElevatedButton(
                  onPressed: _isSavingInfo ? null : _saveProfessionalInfo,
                  child: _isSavingInfo
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
                      OutlinedButton(
                        onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: const Size(0, 34),
                          textStyle: const TextStyle(fontSize: 12.5),
                        ),
                        child: _isUploadingLogo
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: CardioLensColors.primary,
                                ),
                              )
                            : Text(logoUrl == null ? 'Importer' : 'Changer'),
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
