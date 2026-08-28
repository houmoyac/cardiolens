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
    required String fullName,
    required String password,
  }) async {
    final client = ApiClient(baseUrl: apiBaseUrl);
    await client.register(email: email, fullName: fullName, password: password);
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
}
