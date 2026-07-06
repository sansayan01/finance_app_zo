import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// Premium biometric authentication service for the customer portal.
/// Wraps `local_auth` with persistent preference storage.
class CustomerBiometricService {
  static const _prefKey = 'customer_biometric_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Returns true if the device hardware supports biometric authentication.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && deviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Returns the list of enrolled biometric types (fingerprint, face, iris).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Returns a human-readable label for the primary biometric type.
  /// e.g. "Fingerprint", "Face ID", "Iris", or "Biometric".
  Future<String> getBiometricLabel() async {
    final types = await getAvailableBiometrics();
    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
    if (types.contains(BiometricType.iris)) return 'Iris';
    return 'Biometric';
  }

  /// Prompts the user to authenticate via biometric.
  /// Returns true on success, false on failure or cancellation.
  Future<bool> authenticate({
    String reason = 'Authenticate to access your account',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
} on PlatformException {
  return false;
}
  }

  /// Reads the persisted biometric-enabled preference.
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Persists the biometric-enabled preference.
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }
}
