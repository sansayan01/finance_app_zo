import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../repositories/customer_support_repository.dart';
import '../models/customer_ticket_model.dart';
import 'customer_member_provider.dart';

final customerSupportRepositoryProvider =
    Provider<CustomerSupportRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return CustomerSupportRepository(client, orgId);
});

final customerTicketsProvider =
    FutureProvider<List<CustomerTicketModel>>((ref) async {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return [];
  final repository = ref.watch(customerSupportRepositoryProvider);
  return repository.getTickets(customerId);
});

final customerTicketMessagesProvider =
    FutureProvider.family<List<CustomerTicketMessageModel>, String>(
        (ref, ticketId) async {
  final repository = ref.watch(customerSupportRepositoryProvider);
  return repository.getTicketMessages(ticketId);
});

class CreateTicketNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerSupportRepository _repository;
  final Ref _ref;

  CreateTicketNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<bool> createTicket({
    required String customerId,
    required String subject,
    required String message,
    String priority = 'normal',
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createTicket(
        customerId: customerId,
        subject: subject,
        message: message,
        priority: priority,
      );
      _ref.invalidate(customerTicketsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final createTicketProvider =
    StateNotifierProvider<CreateTicketNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(customerSupportRepositoryProvider);
  return CreateTicketNotifier(repository, ref);
});

class TicketMessageNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerSupportRepository _repository;
  final Ref _ref;

  TicketMessageNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<bool> addMessage({
    required String ticketId,
    required String senderId,
    required String message,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.addMessage(
        ticketId: ticketId,
        senderId: senderId,
        message: message,
      );
      _ref.invalidate(customerTicketMessagesProvider(ticketId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final ticketMessageProvider =
    StateNotifierProvider<TicketMessageNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(customerSupportRepositoryProvider);
  return TicketMessageNotifier(repository, ref);
});
