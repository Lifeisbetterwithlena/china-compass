import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase project settings, passed at build time from supabase.json:
///   flutter run --dart-define-from-file=supabase.json
/// Without them the app runs in demo mode (no email is sent; the code is shown on screen).
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
bool get supabaseConfigured => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

/// A login failure with a key into the UI strings (see l10n/strings.dart).
class AuthFailure implements Exception {
  const AuthFailure(this.messageKey);

  final String messageKey;
}

/// Passwordless sign-in: the user enters an email, receives a 6-digit code, and enters it.
abstract class AuthService extends ChangeNotifier {
  String? get email;

  /// Stable id of the signed-in account (null when signed out).
  String? get userId;
  bool get isDemo;

  /// Sends a code to [email]. In demo mode, returns the code so the UI can show it.
  Future<String?> sendCode(String email);
  Future<void> verify(String email, String code);
  Future<void> signOut();
}

class SupabaseAuthService extends AuthService {
  SupabaseAuthService(this._client) {
    _sub = _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _sub;

  @override
  String? get email => _client.auth.currentUser?.email;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  bool get isDemo => false;

  @override
  Future<String?> sendCode(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email, shouldCreateUser: true);
    } on AuthException catch (e) {
      throw AuthFailure(e.statusCode == '429' ? 'errTooManyRequests' : 'errSendFailed');
    } catch (_) {
      throw const AuthFailure('errNetwork');
    }
    return null;
  }

  @override
  Future<void> verify(String email, String code) async {
    try {
      await _client.auth.verifyOTP(type: OtpType.email, email: email, token: code);
    } on AuthException {
      throw const AuthFailure('errWrongCode');
    } catch (_) {
      throw const AuthFailure('errNetwork');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Stand-in until Supabase is configured: behaves like the real flow, but shows the code in the app.
class DemoAuthService extends AuthService {
  DemoAuthService(this._prefs);

  static const _key = 'demo_email';
  final SharedPreferences _prefs;
  String? _pendingEmail;
  String? _pendingCode;

  @override
  String? get email => _prefs.getString(_key);

  @override
  String? get userId => email == null ? null : 'demo:$email';

  @override
  bool get isDemo => true;

  @override
  Future<String?> sendCode(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _pendingEmail = email;
    _pendingCode = (100000 + Random().nextInt(900000)).toString();
    return _pendingCode;
  }

  @override
  Future<void> verify(String email, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (email != _pendingEmail || code != _pendingCode) throw const AuthFailure('errWrongCode');
    _pendingCode = null;
    await _prefs.setString(_key, email);
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    await _prefs.remove(_key);
    notifyListeners();
  }
}
