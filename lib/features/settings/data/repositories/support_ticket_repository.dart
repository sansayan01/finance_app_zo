import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSupportTicket {
  final String id;
  final String subject;
  final String message;
  final String status;
  final String priority;
  final String? assignedTo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AdminSupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminSupportTicket.fromJson(Map<String, dynamic> json) {
    return AdminSupportTicket(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      priority: json['priority']?.toString() ?? 'normal',
      assignedTo: json['assigned_to']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  bool get isOpen => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved' || status == 'closed';
}

class AdminTicketMessage {
  final String id;
  final String ticketId;
  final String senderId;
  final String message;
  final DateTime? createdAt;

  AdminTicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.message,
    this.createdAt,
  });

  factory AdminTicketMessage.fromJson(Map<String, dynamic> json) {
    return AdminTicketMessage(
      id: json['id']?.toString() ?? '',
      ticketId: json['ticket_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class SupportTicketRepository {
  final SupabaseClient _client;
  final String _orgId;

  SupportTicketRepository(this._client, this._orgId);

  Future<List<AdminSupportTicket>> getTicketsForUser(String userId) async {
    try {
      final data = await _client
          .from('customer_support_tickets')
          .select()
          .eq('customer_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      return (data as List)
          .map((e) => AdminSupportTicket.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> createTicket({
    required String userId,
    required String subject,
    required String message,
    String priority = 'normal',
  }) async {
    final data = await _client
        .from('customer_support_tickets')
        .insert({
          'customer_id': userId,
          'subject': subject,
          'message': message,
          'priority': priority,
          'org_id': _orgId,
        })
        .select('id')
        .maybeSingle();

    if (data == null) throw Exception('Failed to create ticket');
    return data['id'] as String;
  }

  Future<List<AdminTicketMessage>> getTicketMessages(String ticketId) async {
    try {
      final data = await _client
          .from('customer_ticket_messages')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
      return (data as List)
          .map((e) =>
              AdminTicketMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
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

    await _client.from('customer_support_tickets').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
  }
}
