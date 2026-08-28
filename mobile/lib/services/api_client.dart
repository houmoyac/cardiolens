import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/ecg_result.dart';

/// Talks to the real CardioLens backend (cardiolens.api:app) — the first
/// piece of the app that isn't static sample data. Points at a local
/// dev server on the same network for now (see ARCHITECTURE.md: no
/// deployed backend exists yet).
class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown by [ApiClient.fetchMe] specifically on a 401 — distinguished from
/// [ApiException] so callers (AuthService.restoreSession) can tell "the
/// token is genuinely invalid, log out" apart from "the network is just
/// unreachable right now, keep the cached session".
class AuthTokenInvalidException implements Exception {}

class AuthUser {
  const AuthUser({required this.id, required this.email, required this.fullName});

  final int id;
  final String email;
  final String fullName;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as int,
    email: json['email'] as String,
    fullName: json['full_name'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'full_name': fullName};
}

class AuthSession {
  const AuthSession({required this.token, required this.user});
  final String token;
  final AuthUser user;
}

class ApiClient {
  ApiClient({required this.baseUrl});

  /// e.g. "http://192.168.1.3:8000" — your Mac's LAN IP while running the
  /// backend locally with `uvicorn cardiolens.api:app --host 0.0.0.0`.
  final String baseUrl;

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<EcgCase> analyze({
    required String patientLabel,
    required String dateLabel,
    required List<double> signal,
    required int samplingRateHz,
    String? sex,
  }) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/analyze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'signal': signal,
              'sampling_rate': samplingRateHz,
              'sex': sex,
            }..removeWhere((_, value) => value == null)),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException(
        "Impossible de joindre le serveur ($baseUrl). Vérifie que le "
        'backend tourne et que ton téléphone est sur le même réseau WiFi.',
      );
    }

    if (response.statusCode == 422) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(body['detail']?.toString() ?? 'Analyse impossible.');
    }
    if (response.statusCode != 200) {
      throw ApiException('Erreur serveur (${response.statusCode}).');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseEcgCase(
      body,
      patientLabel: patientLabel,
      dateLabel: dateLabel,
    );
  }

  Future<AuthUser> register({
    required String email,
    required String fullName,
    required String password,
  }) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'full_name': fullName,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw ApiException(
        "Impossible de joindre le serveur ($baseUrl). Vérifie que le "
        'backend tourne et que ton téléphone est sur le même réseau WiFi.',
      );
    }

    if (response.statusCode == 409) {
      throw ApiException('Un compte existe déjà avec cet email.');
    }
    if (response.statusCode != 201) {
      throw ApiException(_extractDetail(response) ?? 'Inscription impossible.');
    }
    return AuthUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AuthSession> login({required String email, required String password}) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw ApiException(
        "Impossible de joindre le serveur ($baseUrl). Vérifie que le "
        'backend tourne et que ton téléphone est sur le même réseau WiFi.',
      );
    }

    if (response.statusCode == 401) {
      throw ApiException('Email ou mot de passe incorrect.');
    }
    if (response.statusCode != 200) {
      throw ApiException(_extractDetail(response) ?? 'Connexion impossible.');
    }

    final token = (jsonDecode(response.body) as Map<String, dynamic>)['access_token'] as String;
    final user = await fetchMe(token);
    return AuthSession(token: token, user: user);
  }

  Future<AuthUser> fetchMe(String token) async {
    final http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$baseUrl/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      throw ApiException("Impossible de joindre le serveur ($baseUrl).");
    }

    if (response.statusCode == 401) {
      throw AuthTokenInvalidException();
    }
    if (response.statusCode != 200) {
      throw ApiException('Erreur serveur (${response.statusCode}).');
    }
    return AuthUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

String? _extractDetail(http.Response response) {
  try {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['detail']?.toString();
  } catch (_) {
    return null;
  }
}

EcgCase _parseEcgCase(
  Map<String, dynamic> body, {
  required String patientLabel,
  required String dateLabel,
}) {
  final m = body['measurements'] as Map<String, dynamic>;
  final alertsJson = body['alerts'] as List<dynamic>;

  return EcgCase(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    patientLabel: patientLabel,
    dateLabel: dateLabel,
    measurements: EcgMeasurements(
      heartRateBpm: (m['heart_rate_bpm'] as num).toDouble(),
      prIntervalMs: (m['pr_interval_ms'] as num).toDouble(),
      qrsDurationMs: (m['qrs_duration_ms'] as num).toDouble(),
      qtcBazettMs: (m['qtc_ms'] as num).toDouble(),
      qtcFridericiaMs: (m['qtc_fridericia_ms'] as num).toDouble(),
      rrVariabilityPct: (m['rr_variability_pct'] as num).toDouble(),
    ),
    alerts: alertsJson.map((raw) {
      final a = raw as Map<String, dynamic>;
      return ClinicalAlert(
        code: a['code'] as String,
        message: a['message'] as String,
        source: a['source'] == 'ai' ? AlertSource.ai : AlertSource.rule,
        severity: a['severity'] == 'warning'
            ? AlertSeverity.warning
            : AlertSeverity.info,
        confidence: (a['confidence'] as num?)?.toDouble(),
      );
    }).toList(),
  );
}

/// Loads a bundled sample ECG (see assets/sample_ecgs/) as a raw signal —
/// the same CSV files the backend's own test suite and Streamlit tool use.
Future<List<double>> loadBundledSignal(String assetPath) async {
  final csv = await rootBundle.loadString(assetPath);
  return csv
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => double.parse(line.split(',').last))
      .toList();
}
