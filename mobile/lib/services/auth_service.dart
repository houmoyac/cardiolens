import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'api_config.dart';

/// Holds the logged-in doctor's session for the whole app — the JWT and
/// their identity — so any screen (in particular the report's "Validé par"
/// field) can read who is actually using the app right now. Target model:
/// one doctor, one phone, one account — no account-switching UI, just
/// register/login/logout.
///
/// Token and cached identity live in the platform keychain/keystore via
/// flutter_secure_storage, not shared_preferences — it's a credential, not
/// a UI preference.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'cardiolens_auth_token';
  static const _userKey = 'cardiolens_auth_user';

  AuthUser? currentUser;
  String? _token;

  String? get token => _token;
  bool get isLoggedIn => currentUser != null;

  /// Called once at app startup. Tries to resume a previous session:
  /// - No stored token: not logged in.
  /// - Stored token confirmed valid by the backend: logged in, cache refreshed.
  /// - Stored token rejected (expired/revoked): logged out, storage cleared.
  /// - Backend unreachable (WiFi hiccup, laptop asleep): fall back to the
  ///   last-known cached identity rather than stranding the doctor at the
  ///   login screen for a transient network issue.
  Future<bool> restoreSession() async {
    String? token;
    try {
      // Timeout, not just try/catch: some environments (a widget test with
      // no platform channel handler; a wedged keychain) never respond at
      // all rather than throwing — without this, app startup would hang
      // on the loading spinner forever instead of falling back to "not
      // logged in".
      token = await _storage.read(key: _tokenKey).timeout(const Duration(seconds: 3));
    } catch (_) {
      return false;
    }
    if (token == null) return false;

    try {
      final user = await ApiClient(baseUrl: apiBaseUrl).fetchMe(token);
      _token = token;
      currentUser = user;
      await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
      return true;
    } on AuthTokenInvalidException {
      await logout();
      return false;
    } catch (_) {
      final cachedJson = await _storage.read(key: _userKey);
      if (cachedJson == null) return false;
      _token = token;
      currentUser = AuthUser.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
      return true;
    }
  }

  Future<void> register({
    required String email,
    required String firstName,
    required String lastName,
    required String password,
    String? workplace,
  }) async {
    final client = ApiClient(baseUrl: apiBaseUrl);
    await client.register(
      email: email,
      firstName: firstName,
      lastName: lastName,
      password: password,
      workplace: workplace,
    );
    await login(email: email, password: password);
  }

  Future<void> login({required String email, required String password}) async {
    final session = await ApiClient(baseUrl: apiBaseUrl).login(email: email, password: password);
    _token = session.token;
    currentUser = session.user;
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(key: _userKey, value: jsonEncode(session.user.toJson()));
  }

  Future<void> logout() async {
    _token = null;
    currentUser = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  Future<void> updateWorkplace(String? workplace) async {
    final token = _token;
    if (token == null) throw StateError('Not logged in.');
    final user = await ApiClient(
      baseUrl: apiBaseUrl,
    ).updateWorkplace(token: token, workplace: workplace);
    currentUser = user;
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = _token;
    if (token == null) throw StateError('Not logged in.');
    await ApiClient(baseUrl: apiBaseUrl).changePassword(
      token: token,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> uploadLogo(List<int> bytes) async {
    final token = _token;
    if (token == null) throw StateError('Not logged in.');
    final user = await ApiClient(baseUrl: apiBaseUrl).uploadLogo(token: token, bytes: bytes);
    currentUser = user;
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<void> deleteLogo() async {
    final token = _token;
    if (token == null) throw StateError('Not logged in.');
    await ApiClient(baseUrl: apiBaseUrl).deleteLogo(token);
    final current = currentUser;
    if (current != null) {
      currentUser = AuthUser(
        id: current.id,
        email: current.email,
        firstName: current.firstName,
        lastName: current.lastName,
        workplace: current.workplace,
      );
      await _storage.write(key: _userKey, value: jsonEncode(currentUser!.toJson()));
    }
  }

  /// URL for the doctor's uploaded workplace logo — the report/home screen
  /// pass this to Image.network with an Authorization header (the route is
  /// authenticated, same as any other /auth/me/* endpoint). Null when no
  /// logo has been uploaded.
  String? get logoUrl => (currentUser?.hasLogo ?? false) ? '$apiBaseUrl/auth/me/logo' : null;

  Map<String, String> get authHeaders => _token == null ? {} : {'Authorization': 'Bearer $_token'};
}
