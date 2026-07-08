import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../repositories/support_ticket_repository.dart';

final supportTicketServiceProvider = Provider<SupportTicketRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return SupportTicketRepository(client, orgId);
});

final myTicketsProvider =
    FutureProvider<List<AdminSupportTicket>>((ref) async {
  final service = ref.watch(supportTicketServiceProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return service.getTicketsForUser(user.id);
});

final ticketMessagesProvider =
    FutureProvider.family<List<AdminTicketMessage>, String>((ref, ticketId) async {
  final service = ref.watch(supportTicketServiceProvider);
  return service.getTicketMessages(ticketId);
});
