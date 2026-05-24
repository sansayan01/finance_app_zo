import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer_notification_preferences.dart';

/// Loads and persists [CustomerNotificationPreferences] from SharedPreferences.
///
/// Starts with [CustomerNotificationPreferences.defaults] until the real
/// value is read from disk.
class CustomerNotificationPreferencesNotifier
    extends AsyncNotifier<CustomerNotificationPreferences> {
  @override
  Future<CustomerNotificationPreferences> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CustomerNotificationPreferences.storageKey);
    if (raw == null) return CustomerNotificationPreferences.defaults;
    return CustomerNotificationPreferences.fromJsonString(raw);
  }

  /// Persist a fully replaced [CustomerNotificationPreferences] object.
  Future<void> updatePreferences(
    CustomerNotificationPreferences preferences,
  ) async {
    state = AsyncData(preferences);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CustomerNotificationPreferences.storageKey,
      preferences.toJsonString(),
    );
  }

  /// Convenience: toggle a single boolean field by name.
  Future<void> toggle(String field, bool value) async {
    final current = state.valueOrNull ?? CustomerNotificationPreferences.defaults;
    CustomerNotificationPreferences updated;
    switch (field) {
      case 'pushEnabled':
        updated = current.copyWith(pushEnabled: value);
        break;
      case 'emailEnabled':
        updated = current.copyWith(emailEnabled: value);
        break;
      case 'emiReminder3Days':
        updated = current.copyWith(emiReminder3Days: value);
        break;
      case 'emiReminder1Day':
        updated = current.copyWith(emiReminder1Day: value);
        break;
      case 'emiReminderOnDue':
        updated = current.copyWith(emiReminderOnDue: value);
        break;
      case 'paymentConfirmation':
        updated = current.copyWith(paymentConfirmation: value);
        break;
      case 'savingsMilestone':
        updated = current.copyWith(savingsMilestone: value);
        break;
      case 'systemAlerts':
        updated = current.copyWith(systemAlerts: value);
        break;
      default:
        return; // Unknown field -- ignore.
    }
    await updatePreferences(updated);
  }

  /// Reset all preferences back to defaults.
  Future<void> resetToDefaults() async {
    await updatePreferences(CustomerNotificationPreferences.defaults);
  }
}

/// Public provider that UI widgets should `.watch()` or `.read()`.
final customerNotificationPreferencesProvider = AsyncNotifierProvider<
    CustomerNotificationPreferencesNotifier,
    CustomerNotificationPreferences>(
  () => CustomerNotificationPreferencesNotifier(),
);
