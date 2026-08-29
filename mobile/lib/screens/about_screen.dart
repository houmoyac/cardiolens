import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('À propos', style: TextStyle(fontSize: 15))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/logo.png', height: 28),
                      const SizedBox(width: 10),
                      const Text(
                        'CardioLens',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      return Text(
                        info == null ? 'Version…' : 'Version ${info.version} (${info.buildNumber})',
                        style: const TextStyle(fontSize: 12.5, color: CardioLensColors.textSecondary),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "CardioLens est un outil d'aide à l'interprétation ECG "
                    '(mesures et alertes fondées sur des seuils cliniques publiés, '
                    'plus un signal algorithmique de suspicion de fibrillation '
                    "atriale). Il ne remplace pas le jugement médical : chaque "
                    "compte-rendu doit être validé par un médecin avant toute "
                    'décision clinique.',
                    style: TextStyle(fontSize: 13, height: 1.5),
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
