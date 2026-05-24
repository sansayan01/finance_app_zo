import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/customer_biometric_service.dart';

/// Singleton instance of the biometric service.
final customerBiometricServiceProvider = Provider<CustomerBiometricService>(
  (ref) => CustomerBiometricService(),
);

/// Async provider that reads the persisted biometric-enabled state.
final customerBiometricEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(customerBiometricServiceProvider);
  return service.isBiometricEnabled();
});

/// Async provider for the human-readable biometric label
/// (e.g. "Fingerprint", "Face ID").
final customerBiometricLabelProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(customerBiometricServiceProvider);
  return service.getBiometricLabel();
});

/// Async provider that checks if the device supports biometric at all.
final customerBiometricAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(customerBiometricServiceProvider);
  return service.isBiometricAvailable();
});

/// Notifier that toggles biometric authentication on/off.
/// On enable, runs an authentication prompt first; on disable, persists directly.
class BiometricToggleNotifier extends StateNotifier<AsyncValue<bool>> {
  final CustomerBiometricService _service;
  final Ref _ref;

  BiometricToggleNotifier(this._service, this._ref)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await _service.isBiometricEnabled();
      state = AsyncValue.data(enabled);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Toggles biometric. Returns true if the new state was applied.
  Future<bool> toggle(bool enable) async {
    if (enable) {
      // Verify the user can authenticate before enabling
      final didAuthenticate = await _service.authenticate(
        reason: 'Verify your identity to enable biometric login',
      );
      if (!didAuthenticate) return false;
    }

    await _service.setBiometricEnabled(enable);
    state = AsyncValue.data(enable);
    _ref.invalidate(customerBiometricEnabledProvider);
    return true;
  }
}

final customerBiometricToggleProvider = StateNotifierProvider<
    BiometricToggleNotifier, AsyncValue<bool>>((ref) {
  final service = ref.watch(customerBiometricServiceProvider);
  return BiometricToggleNotifier(service, ref);
});
