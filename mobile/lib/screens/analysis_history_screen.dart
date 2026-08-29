import 'package:flutter/material.dart';

import '../models/ecg_result.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'results_screen.dart';

/// The doctor's real, saved analysis history (see /cases on the backend —
/// every /analyze call made while logged in is archived there
/// automatically). Not the "Exemples" PTB-XL demo cases on the home
/// screen — this is only ever real data, or empty.
class AnalysisHistoryScreen extends StatefulWidget {
  const AnalysisHistoryScreen({super.key});

  @override
  State<AnalysisHistoryScreen> createState() => _AnalysisHistoryScreenState();
}

class _AnalysisHistoryScreenState extends State<AnalysisHistoryScreen> {
  late Future<List<EcgCase>> _casesFuture = _load();

  Future<List<EcgCase>> _load() {
    final token = AuthService.instance.token;
    if (token == null) return Future.value(const []);
    return ApiClient(baseUrl: apiBaseUrl).fetchCases(token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des analyses', style: TextStyle(fontSize: 15))),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _casesFuture = _load()),
        child: FutureBuilder<List<EcgCase>>(
          future: _casesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Text(
                      'Historique indisponible pour le moment.',
                      style: TextStyle(color: CardioLensColors.textMuted),
                    ),
                  ),
                ],
              );
            }
            final cases = snapshot.data ?? const [];
            if (cases.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        "Aucune analyse enregistrée pour l'instant — importe un ECG "
                        'depuis l\'accueil pour commencer.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: CardioLensColors.textMuted),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: cases.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ecgCase = cases[index];
                final ok = !ecgCase.hasWarning;
                return Material(
                  color: CardioLensColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ResultsScreen(ecgCase: ecgCase)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CardioLensColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: ok ? CardioLensColors.okBg : CardioLensColors.alertBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.monitor_heart_outlined,
                              size: 16,
                              color: ok ? CardioLensColors.okText : CardioLensColors.alertAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ecgCase.patientLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  ecgCase.dateLabel,
                                  style: const TextStyle(
                                    color: CardioLensColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ok ? CardioLensColors.okBg : CardioLensColors.alertBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ok ? 'Normal' : 'Anomalie',
                              style: TextStyle(
                                color: ok
                                    ? CardioLensColors.okText
                                    : CardioLensColors.alertAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
