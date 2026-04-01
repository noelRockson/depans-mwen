import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../local/local_db.dart';

void _log(String msg) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[Session] $msg');
  }
}

enum SessionTimeoutPolicy {
  never,
  days7,
  days30,
  days90,
}

extension SessionTimeoutPolicyX on SessionTimeoutPolicy {
  int get asDaysOrNegative {
    switch (this) {
      case SessionTimeoutPolicy.never:
        return -1;
      case SessionTimeoutPolicy.days7:
        return 7;
      case SessionTimeoutPolicy.days30:
        return 30;
      case SessionTimeoutPolicy.days90:
        return 90;
    }
  }
}

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  SharedPreferences? _prefs;
  final LocalAuthentication _localAuth = LocalAuthentication();

  final ValueNotifier<bool> onboardingCompleted = ValueNotifier<bool>(false);

  UserModel? _activeUser;

  static const _kBiometricEnabledSuffix = 'biometric_enabled';
  static const _kBiometricAfterMinutesSuffix = 'biometric_after_minutes';
  static const _kSessionTimeoutDaysSuffix = 'session_timeout_days';
  static const _kLastActivityAtSuffix = 'last_activity_at';
  static const _kOnboardingCompletedSuffix = 'onboarding_completed';

  static const _kGlobalIsSignedIn = 'session_is_signed_in';
  static const _kGlobalUserId = 'session_user_id';

  bool get _prefsReady => _prefs != null;

  String _userKey(String suffix, {String? userIdOverride}) {
    final userId = userIdOverride ?? _activeUser?.id;
    if (userId == null) return suffix;
    return '${suffix}_$userId';
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await LocalDb.instance.init();
  }

  Future<void> bindUser(UserModel user) async {
    _log('bindUser uid=${user.id} provider=${user.provider}');
    _activeUser = user;
    await _prefs?.setBool(_kGlobalIsSignedIn, true);
    await _prefs?.setString(_kGlobalUserId, user.id);
    await _loadOnboardingFromLocal(user.id);

    // Auto-complete onboarding for OAuth users (Google / Apple).
    final isOAuth = user.provider == 'google.com' || user.provider == 'apple.com';
    if (isOAuth && !onboardingCompleted.value) {
      _log('bindUser: OAuth user without onboarding -> auto-completing');
      onboardingCompleted.value = true;
      await _prefs?.setBool(
        _userKey(_kOnboardingCompletedSuffix, userIdOverride: user.id),
        true,
      );
    }
    _log('bindUser: onboardingCompleted=${onboardingCompleted.value} biometric=$biometricEnabled');
  }

  Future<void> unbindUser() async {
    _activeUser = null;
    await _prefs?.setBool(_kGlobalIsSignedIn, false);
    await _prefs?.setString(_kGlobalUserId, '');
    onboardingCompleted.value = false;
  }

  int _defaultBiometricAfterMinutes() => 5;
  int _defaultSessionTimeoutDays() => 30;

  bool get biometricEnabled {
    if (!_prefsReady) return false;
    if (_activeUser == null) return false;
    return _prefs!.getBool(
          _userKey(_kBiometricEnabledSuffix),
        ) ??
        false;
  }

  int get biometricAfterMinutes {
    if (!_prefsReady) return _defaultBiometricAfterMinutes();
    if (_activeUser == null) return _defaultBiometricAfterMinutes();
    return _prefs!.getInt(
          _userKey(_kBiometricAfterMinutesSuffix),
        ) ??
        _defaultBiometricAfterMinutes();
  }

  int get sessionTimeoutDays {
    if (!_prefsReady) return _defaultSessionTimeoutDays();
    if (_activeUser == null) return _defaultSessionTimeoutDays();
    return _prefs!.getInt(
          _userKey(_kSessionTimeoutDaysSuffix),
        ) ??
        _defaultSessionTimeoutDays();
  }

  DateTime? get lastActivityAt {
    if (!_prefsReady) return null;
    if (_activeUser == null) return null;
    final ms = _prefs!.getInt(_userKey(_kLastActivityAtSuffix));
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> touch() async {
    if (_activeUser == null || !_prefsReady) return;
    final now = DateTime.now();
    await _prefs!.setInt(_userKey(_kLastActivityAtSuffix), now.millisecondsSinceEpoch);
  }

  Future<bool> isSessionTimedOut() async {
    final user = _activeUser;
    if (user == null || !_prefsReady) return false;

    final timeoutDays = sessionTimeoutDays;
    if (timeoutDays < 0) {
      _log('isSessionTimedOut: policy=never -> false');
      return false;
    }

    final last = lastActivityAt;
    if (last == null) {
      _log('isSessionTimedOut: no lastActivityAt -> false (first login)');
      return false;
    }

    final diffDays = DateTime.now().difference(last).inDays;
    final timedOut = diffDays >= timeoutDays;
    _log('isSessionTimedOut: lastActivity=${last.toIso8601String()} diffDays=$diffDays timeout=$timeoutDays -> $timedOut');
    return timedOut;
  }

  Future<void> lockoutAndSignOut() async {
    _log('lockoutAndSignOut called');
    await AuthService.instance.signOut();
    await unbindUser();
  }

  Future<void> _loadOnboardingFromLocal(String userId) async {
    final value = _prefs?.getBool(_userKey(_kOnboardingCompletedSuffix, userIdOverride: userId));
    onboardingCompleted.value = value ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    final user = _activeUser;
    if (user == null || !_prefsReady) return;
    onboardingCompleted.value = value;
    await _prefs!.setBool(_userKey(_kOnboardingCompletedSuffix), value);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .set(
            {
              'onboarding_completed': value,
              'last_updated_at': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      _log('setOnboardingCompleted sync failed: $e');
    }
  }

  Future<void> refreshOnboardingFromRemoteBestEffort() async {
    final user = _activeUser;
    if (user == null || !_prefsReady) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .get()
          .timeout(const Duration(seconds: 4));

      final data = snap.data();
      _log('refreshOnboarding: remote data=$data');
      final remoteValue = data?['onboarding_completed'];
      if (remoteValue is bool) {
        onboardingCompleted.value = remoteValue;
        await _prefs!.setBool(_userKey(_kOnboardingCompletedSuffix), remoteValue);
      }
    } catch (e) {
      _log('refreshOnboardingFromRemoteBestEffort failed: $e');
    }
  }

  Future<bool> canBiometricAuthenticate() async {
    if (!biometricEnabled) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> promptBiometricUnlock() async {
    if (!biometricEnabled) {
      _log('promptBiometricUnlock: biometric disabled -> allow');
      return true;
    }

    final can = await canBiometricAuthenticate();
    if (!can) {
      // Device cannot perform biometrics: graceful fallback (allow access).
      _log('promptBiometricUnlock: device cannot biometric -> allow');
      return true;
    }

    try {
      _log('promptBiometricUnlock: prompting user...');
      final result = await _localAuth.authenticate(
        localizedReason: 'Déverrouiller l\'application',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: false,
      );
      _log('promptBiometricUnlock: result=$result');
      return result;
    } catch (e) {
      _log('promptBiometricUnlock: error=$e -> allow (graceful fallback)');
      return true;
    }
  }

  Future<void> updateBiometricEnabled(bool value) async {
    if (_activeUser == null || !_prefsReady) return;
    await _prefs!.setBool(_userKey(_kBiometricEnabledSuffix), value);
  }

  Future<void> updateBiometricAfterMinutes(int minutes) async {
    if (_activeUser == null || !_prefsReady) return;
    await _prefs!.setInt(_userKey(_kBiometricAfterMinutesSuffix), minutes);
  }

  Future<void> updateSessionTimeoutDays(int daysOrNegativeNever) async {
    if (_activeUser == null || !_prefsReady) return;
    await _prefs!.setInt(_userKey(_kSessionTimeoutDaysSuffix), daysOrNegativeNever);
  }
}
