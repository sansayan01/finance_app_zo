import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../services/customer_notification_service.dart';
import 'customer_member_provider.dart';

/// Provides a singleton [CustomerNotificationService] wired to the Supabase
/// client.
final customerNotificationServiceProvider =
    Provider<CustomerNotificationService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CustomerNotificationService(client);
});

/// Triggers smart notification generation on every app launch (or whenever the
/// customer id / org id changes). This is a [FutureProvider] so downstream
/// widgets can `.watch()` it to know when the check has completed.
///
/// Safe to call repeatedly -- duplicate notifications are suppressed inside
/// [CustomerNotificationService].
final smartNotificationTriggerProvider = FutureProvider<void>((ref) async {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return;

  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  final service = ref.watch(customerNotificationServiceProvider);

  // Fire all smart notification checks in parallel.
  await service.generateSmartNotifications(customerId, orgId);

  // Also prune notifications older than 30 days.
  await service.cleanupOldNotifications(customerId);
});
