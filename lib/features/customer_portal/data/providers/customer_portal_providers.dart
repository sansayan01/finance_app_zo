import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../repositories/customer_portal_repository.dart';
import '../models/customer_portal_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Customer Portal Repository Provider
final customerPortalRepositoryProvider = Provider<CustomerPortalRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CustomerPortalRepository(client);
});

/// Customer Dashboard Provider
final customerDashboardProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, memberId) async {
  final repository = ref.watch(customerPortalRepositoryProvider);
  return repository.getCustomerDashboard(memberId);
});

/// Customer Loans Provider
final customerLoansProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final repository = ref.watch(customerPortalRepositoryProvider);
  return repository.getCustomerLoans(memberId);
});

/// Customer Savings Provider
final customerSavingsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final repository = ref.watch(customerPortalRepositoryProvider);
  return repository.getCustomerSavings(memberId);
});

/// Customer Transactions Provider
final customerTransactionsProvider = FutureProvider.family<List<Map<String, dynamic>>, (String, int?)>((ref, params) async {
  final repository = ref.watch(customerPortalRepositoryProvider);
  return repository.getCustomerTransactions(params.$1, limit: params.$2);
});

/// Customer Notifications Provider
final customerNotificationsProvider = FutureProvider.family<List<CustomerNotification>, String>((ref, memberId) async {
  final repository = ref.watch(customerPortalRepositoryProvider);
  return repository.getNotifications(memberId);
});

/// Current Member ID Provider
final currentMemberIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).user;
  return user?.memberId ?? user?.id;
});

/// EMI Payment Notifier
class EMIPaymentNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerPortalRepository _repository;
  final Ref _ref;

  EMIPaymentNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<bool> payEMI(String loanId, double amount, String paymentMode) async {
    state = const AsyncValue.loading();
    try {
      await _repository.processEMIPayment(loanId, amount, paymentMode);
      _ref.invalidate(customerLoansProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final emiPaymentProvider = StateNotifierProvider<EMIPaymentNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(customerPortalRepositoryProvider);
  return EMIPaymentNotifier(repository, ref);
});

/// Savings Deposit Notifier
class SavingsDepositNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerPortalRepository _repository;
  final Ref _ref;

  SavingsDepositNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<bool> deposit(String accountId, double amount) async {
    state = const AsyncValue.loading();
    try {
      await _repository.processSavingsDeposit(accountId, amount);
      _ref.invalidate(customerSavingsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> withdraw(String accountId, double amount, String reason) async {
    state = const AsyncValue.loading();
    try {
      await _repository.processSavingsWithdrawal(accountId, amount, reason);
      _ref.invalidate(customerSavingsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final savingsDepositProvider = StateNotifierProvider<SavingsDepositNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(customerPortalRepositoryProvider);
  return SavingsDepositNotifier(repository, ref);
});

/// Support Ticket Notifier
class SupportTicketNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerPortalRepository _repository;
  final Ref _ref;

  SupportTicketNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<bool> createTicket(String customerId, String subject, String message, {String? category}) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createSupportTicket(
        customerId: customerId,
        subject: subject,
        message: message,
      );
      _ref.invalidate(customerNotificationsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final supportTicketProvider = StateNotifierProvider<SupportTicketNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(customerPortalRepositoryProvider);
  return SupportTicketNotifier(repository, ref);
});

/// Mark Notification as Read
class NotificationNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerPortalRepository _repository;
  final Ref _ref;

  NotificationNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markNotificationRead(notificationId);
      _ref.invalidate(customerNotificationsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAllAsRead(String memberId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.markAllNotificationsRead(memberId);
      _ref.invalidate(customerNotificationsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final notificationNotifierProvider = StateNotifierProvider<NotificationNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(customerPortalRepositoryProvider);
  return NotificationNotifier(repository, ref);
});

