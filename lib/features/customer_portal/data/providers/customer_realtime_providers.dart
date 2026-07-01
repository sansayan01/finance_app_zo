import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import 'customer_member_provider.dart';
import 'customer_notifications_providers.dart';
import 'customer_support_providers.dart';
import 'customer_profile_providers.dart';
import 'customer_home_providers.dart';
import 'customer_savings_providers.dart';

/// Realtime stream of new notifications for the current customer.
/// Auto-disposes when the last listener goes away (logout / route change).
final realtimeNotificationsProvider = StreamProvider.autoDispose<int>((ref) {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return const Stream.empty();

  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>();

  // Push initial value
  controller.add(0);

  final channel = client
      .channel('customer_notifications_$customerId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'customer_notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'customer_id',
          value: customerId,
        ),
        callback: (payload) {
          // Invalidate the notifications providers so the UI refetches
          ref.invalidate(customerNotificationsProvider);
          ref.invalidate(customerUnreadCountProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

/// Realtime stream of new support messages for a specific ticket.
/// Auto-disposes when the last listener goes away.
final realtimeTicketMessagesProvider =
    StreamProvider.autoDispose.family<void, String>((ref, ticketId) {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return const Stream.empty();

  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<void>();

  final channel = client
      .channel('ticket_messages_$ticketId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'customer_ticket_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'ticket_id',
          value: ticketId,
        ),
        callback: (payload) {
          // Invalidate the message provider for this ticket
          ref.invalidate(customerTicketMessagesProvider(ticketId));
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

/// Realtime stream of member profile changes (KYC, profile fields).
/// Auto-disposes when the last listener goes away.
final realtimeMemberProfileProvider = StreamProvider.autoDispose<void>((ref) {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return const Stream.empty();

  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<void>();

  final channel = client
      .channel('member_profile_$customerId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: customerId,
        ),
        callback: (payload) {
          ref.invalidate(customerProfileProvider);
          // Also invalidate the dashboard so KYC banner refreshes
          ref.invalidate(customerDashboardProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

/// Realtime stream of savings transaction + collection changes for a specific savings plan.
/// Invalidates the transaction and collection-date providers whenever a row is inserted, updated, or deleted.
final realtimeSavingsTransactionsProvider =
    StreamProvider.autoDispose.family<void, String>((ref, savingsId) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<void>();

  // Listen to transactions table for this savings plan
  final txChannel = client
      .channel('savings_tx_$savingsId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'transactions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'savings_id',
          value: savingsId,
        ),
        callback: (payload) {
          ref.invalidate(customerSavingsTransactionsProvider(savingsId));
        },
      )
      .subscribe();

  // Listen to savings_collections table for this savings plan
  final colChannel = client
      .channel('savings_collections_$savingsId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'savings_collections',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'savings_plan_id',
          value: savingsId,
        ),
        callback: (payload) {
          ref.invalidate(savingsCollectionDatesProvider(savingsId));
          ref.invalidate(savingsCollectorNamesProvider(savingsId));
          ref.invalidate(customerSavingsDetailProvider(savingsId));
        },
      )
      .subscribe();

  ref.onDispose(() {
    txChannel.unsubscribe();
    colChannel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});
