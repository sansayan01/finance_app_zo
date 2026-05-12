import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/storage_providers.dart';

/// Security service for authentication and security features
class SecurityService {
  final LocalAuthentication _localAuth;
  final SharedPreferences _prefs;

  static const String _pinKey = 'security_pin';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _autoLockKey = 'auto_lock_minutes';
  static const String _lastActivityKey = 'last_activity';

  SecurityService(this._localAuth, this._prefs);

  /// Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics({
    String localizedReason = 'Authenticate to continue',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
      );
    } catch (_) {
      return false;
    }
  }

  /// Set PIN
  Future<void> setPin(String pin) async {
    await _prefs.setString(_pinKey, pin);
  }

  /// Verify PIN
  Future<bool> verifyPin(String pin) async {
    final storedPin = _prefs.getString(_pinKey);
    return storedPin == pin;
  }

  /// Check if PIN is set
  bool hasPin() {
    return _prefs.containsKey(_pinKey);
  }

  /// Clear PIN
  Future<void> clearPin() async {
    await _prefs.remove(_pinKey);
  }

  /// Enable/disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_biometricEnabledKey, enabled);
  }

  /// Check if biometric is enabled
  bool isBiometricEnabled() {
    return _prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Set auto-lock timeout in minutes
  Future<void> setAutoLockMinutes(int minutes) async {
    await _prefs.setInt(_autoLockKey, minutes);
  }

  /// Get auto-lock timeout
  int getAutoLockMinutes() {
    return _prefs.getInt(_autoLockKey) ?? 5;
  }

  /// Update last activity timestamp
  Future<void> updateLastActivity() async {
    await _prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
  }

  /// Check if app should be locked due to inactivity
  bool shouldLockDueToInactivity() {
    if (!hasPin()) return false;

    final lastActivityStr = _prefs.getString(_lastActivityKey);
    if (lastActivityStr == null) return false;

    final lastActivity = DateTime.tryParse(lastActivityStr);
    if (lastActivity == null) return false;

    final autoLockMinutes = getAutoLockMinutes();
    final lockAfter = lastActivity.add(Duration(minutes: autoLockMinutes));

    return DateTime.now().isAfter(lockAfter);
  }

  /// Clear all security settings
  Future<void> clearAllSecuritySettings() async {
    await _prefs.remove(_pinKey);
    await _prefs.remove(_biometricEnabledKey);
    await _prefs.remove(_autoLockKey);
    await _prefs.remove(_lastActivityKey);
  }
}

/// Security service provider
final securityServiceProvider = Provider<SecurityService>((ref) {
  final localAuth = LocalAuthentication();
  final prefs = ref.watch(sharedPreferencesProvider);
  return SecurityService(localAuth, prefs);
});

/// Biometric availability provider
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(securityServiceProvider);
  return service.isBiometricAvailable();
});

/// Available biometrics provider
final availableBiometricsProvider = FutureProvider<List<BiometricType>>((ref) async {
  final service = ref.watch(securityServiceProvider);
  return service.getAvailableBiometrics();
});

/// Security settings provider
final securitySettingsProvider = Provider<SecuritySettings>((ref) {
  final service = ref.watch(securityServiceProvider);
  return SecuritySettings(
    hasPin: service.hasPin(),
    biometricEnabled: service.isBiometricEnabled(),
    autoLockMinutes: service.getAutoLockMinutes(),
  );
});

/// Security settings model
class SecuritySettings {
  final bool hasPin;
  final bool biometricEnabled;
  final int autoLockMinutes;

  SecuritySettings({
    required this.hasPin,
    required this.biometricEnabled,
    required this.autoLockMinutes,
  });
}
