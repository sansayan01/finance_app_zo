import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_ticket_model.dart';

class CustomerSupportRepository {
  final SupabaseClient _client;
  final String _orgId;

  CustomerSupportRepository(this._client, this._orgId);

  Future<List<CustomerTicketModel>> getTickets(String customerId) async {
    try {
      final data = await _client
          .from('customer_support_tickets')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false)
          .limit(50);
      return (data as List)
          .map((e) => CustomerTicketModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<String> createTicket({
    required String customerId,
    required String subject,
    required String message,
    String priority = 'normal',
  }) async {
    final data = await _client
        .from('customer_support_tickets')
        .insert({
          'customer_id': customerId,
          'subject': subject,
          'message': message,
          'priority': priority,
          'org_id': _orgId,
        })
        .select('id')
        .maybeSingle();

    if (data == null) {
      throw Exception('Failed to create support ticket');
    }

    return data['id'] as String;
  }

  Future<List<CustomerTicketMessageModel>> getTicketMessages(
      String ticketId) async {
    try {
      final data = await _client
          .from('customer_ticket_messages')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
      return (data as List)
          .map((e) =>
              CustomerTicketMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addMessage({
    required String ticketId,
    required String senderId,
    required String message,
  }) async {
    await _client.from('customer_ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_id': senderId,
      'message': message,
    });

    // Update ticket updated_at
    await _client.from('customer_support_tickets').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
  }
}
