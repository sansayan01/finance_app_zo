import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../models/customer_notification_preferences.dart';
import '../repositories/customer_notification_preferences_repository.dart';
import 'customer_member_provider.dart';

/// Repository provider for server-side notification preferences sync.
final customerNotificationPreferencesRepositoryProvider =
    Provider<CustomerNotificationPreferencesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return CustomerNotificationPreferencesRepository(client, orgId);
});

/// Loads and persists [CustomerNotificationPreferences] from SharedPreferences.
///
/// Starts with [CustomerNotificationPreferences.defaults] until the real
/// value is read from disk. After the local read, attempts a fire-and-forget
/// Supabase read to merge in any server-side values.
class CustomerNotificationPreferencesNotifier
    extends AsyncNotifier<CustomerNotificationPreferences> {
  @override
  Future<CustomerNotificationPreferences> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CustomerNotificationPreferences.storageKey);
    final local = raw == null
        ? CustomerNotificationPreferences.defaults
        : CustomerNotificationPreferences.fromJsonString(raw);

    // Fire-and-forget: try to merge server-side values, then update state.
    // We do not await this — UI should render with local data first.
    _mergeFromServer();
    return local;
  }

  Future<void> _mergeFromServer() async {
    try {
      final customerId = ref.read(currentCustomerIdSyncProvider);
      if (customerId == null || customerId.isEmpty) return;
      final repo = ref.read(
        customerNotificationPreferencesRepositoryProvider,
      );
      final remote = await repo.getForCustomer(customerId);
      if (remote != state.valueOrNull) {
        state = AsyncData(remote);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          CustomerNotificationPreferences.storageKey,
          remote.toJsonString(),
        );
      }
    } catch (_) {
      // Server sync is best-effort; ignore failures.
    }
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
    // Fire-and-forget server sync.
    _upsertToServer(preferences);
  }

  Future<void> _upsertToServer(
    CustomerNotificationPreferences preferences,
  ) async {
    try {
      final customerId = ref.read(currentCustomerIdSyncProvider);
      if (customerId == null || customerId.isEmpty) return;
      final repo = ref.read(
        customerNotificationPreferencesRepositoryProvider,
      );
      await repo.upsert(customerId, preferences);
    } catch (_) {
      // Server sync is best-effort; ignore failures.
    }
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
