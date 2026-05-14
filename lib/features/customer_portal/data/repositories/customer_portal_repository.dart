import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_portal_models.dart';

class CustomerPortalRepository {
  final SupabaseClient _client;

  CustomerPortalRepository(this._client);

  // ================== NOTIFICATIONS ==================

  /// Get all notifications for the customer
  Future<List<CustomerNotification>> getNotifications(String customerId) async {
    final response = await _client
        .from('customer_notifications')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return response
        .map<CustomerNotification>((json) => CustomerNotification.fromJson(json))
        .toList();
  }

  /// Mark notification as read
  Future<void> markNotificationRead(String notificationId) async {
    await _client.from('customer_notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId);
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsRead(String customerId) async {
    await _client.from('customer_notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('customer_id', customerId).eq('is_read', false);
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount(String customerId) async {
    final response = await _client
        .from('customer_notifications')
        .select('id')
        .eq('customer_id', customerId)
        .eq('is_read', false);

    return response.length;
  }

  // ================== PAYMENT REQUESTS ==================

  /// Create a payment request
  Future<CustomerPaymentRequest> createPaymentRequest({
    required String customerId,
    String? loanId,
    required double amount,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    final response = await _client
        .from('customer_payment_requests')
        .insert({
          'customer_id': customerId,
          'loan_id': loanId,
          'amount': amount,
          'payment_method': paymentMethod,
          'notes': notes,
        })
        .select()
        .single();

    return CustomerPaymentRequest.fromJson(response);
  }

  /// Get all payment requests for a customer
  Future<List<CustomerPaymentRequest>> getPaymentRequests(String customerId) async {
    final response = await _client
        .from('customer_payment_requests')
        .select()
        .eq('customer_id', customerId)
        .order('requested_at', ascending: false);

    return response
        .map<CustomerPaymentRequest>((json) => CustomerPaymentRequest.fromJson(json))
        .toList();
  }

  /// Cancel a payment request
  Future<void> cancelPaymentRequest(String requestId) async {
    await _client.from('customer_payment_requests').delete().eq('id', requestId);
  }

  // ================== SUPPORT TICKETS ==================

  /// Create a support ticket
  Future<CustomerSupportTicket> createSupportTicket({
    required String customerId,
    required String subject,
    required String message,
    TicketPriority priority = TicketPriority.normal,
  }) async {
    String priorityString = 'normal';
    switch (priority) {
      case TicketPriority.low:
        priorityString = 'low';
        break;
      case TicketPriority.high:
        priorityString = 'high';
        break;
      case TicketPriority.urgent:
        priorityString = 'urgent';
        break;
      default:
        priorityString = 'normal';
    }

    final response = await _client
        .from('customer_support_tickets')
        .insert({
          'customer_id': customerId,
          'subject': subject,
          'message': message,
          'priority': priorityString,
        })
        .select()
        .single();

    return CustomerSupportTicket.fromJson(response);
  }

  /// Get all support tickets for a customer
  Future<List<CustomerSupportTicket>> getSupportTickets(String customerId) async {
    final response = await _client
        .from('customer_support_tickets')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return response
        .map<CustomerSupportTicket>((json) => CustomerSupportTicket.fromJson(json))
        .toList();
  }

  /// Add message to a ticket
  Future<void> addTicketMessage({
    required String ticketId,
    required String senderId,
    required String message,
    List<String>? attachments,
  }) async {
    await _client.from('customer_ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_id': senderId,
      'message': message,
      'attachments': attachments ?? [],
    });

    // Update ticket's updated_at
    await _client.from('customer_support_tickets').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
  }

  /// Get messages for a ticket
  Future<List<Map<String, dynamic>>> getTicketMessages(String ticketId) async {
    final response = await _client
        .from('customer_ticket_messages')
        .select('''
          id,
          message,
          created_at,
          attachments,
          sender:profiles!customer_ticket_messages_sender_id_fkey(id, name, phone, role)
        ''')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);

    return response;
  }

  // ================== FEEDBACK ==================

  /// Submit feedback
  Future<CustomerFeedback> submitFeedback({
    required String customerId,
    required String type,
    String? subject,
    required String message,
    int? rating,
  }) async {
    final response = await _client
        .from('customer_feedback')
        .insert({
          'customer_id': customerId,
          'type': type,
          'subject': subject,
          'message': message,
          'rating': rating,
        })
        .select()
        .single();

    return CustomerFeedback.fromJson(response);
  }

  /// Get customer's feedback history
  Future<List<CustomerFeedback>> getFeedbackHistory(String customerId) async {
    final response = await _client
        .from('customer_feedback')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return response
        .map<CustomerFeedback>((json) => CustomerFeedback.fromJson(json))
        .toList();
  }

  // ================== LOANS & SAVINGS ==================

  /// Get customer's loans
  Future<List<Map<String, dynamic>>> getCustomerLoans(String customerId) async {
    final response = await _client
        .from('loans')
        .select('''
          id,
          loan_id,
          principal_amount,
          interest_rate,
          tenure_months,
          emi_amount,
          outstanding_balance,
          status,
          disbursed_date,
          maturity_date,
          loan_purpose,
          branch:branches(id, name),
          collected_amount,
          next_emi_date,
          next_emi_amount
        ''')
        .eq('member_id', customerId)
        .order('created_at', ascending: false);

    return response;
  }

  /// Get EMI schedule for a loan
  Future<List<Map<String, dynamic>>> getEMISchedule(String loanId) async {
    final response = await _client
        .from('emi_schedule')
        .select()
        .eq('loan_id', loanId)
        .order('emi_number', ascending: true);

    return response;
  }

  /// Get customer's savings
  Future<List<Map<String, dynamic>>> getCustomerSavings(String customerId) async {
    final response = await _client
        .from('savings_accounts')
        .select('''
          id,
          account_number,
          balance,
          interest_rate,
          status,
          created_at,
          savings_plan:savings_plans(id, name, type)
        ''')
        .eq('member_id', customerId);

    return response;
  }

  /// Get savings transactions
  Future<List<Map<String, dynamic>>> getSavingsTransactions(String savingsAccountId) async {
    final response = await _client
        .from('transactions')
        .select()
        .eq('savings_account_id', savingsAccountId)
        .order('transaction_date', ascending: false);

    return response;
  }

  /// Get customer profile
  Future<Map<String, dynamic>?> getCustomerProfile(String customerId) async {
    final response = await _client
        .from('profiles')
        .select('''
          id,
          name,
          email,
          phone,
          role,
          created_at,
          member_id,
          kyc_status,
          branch:branches(id, name)
        ''')
        .eq('id', customerId)
        .single();

    return response;
  }

  /// Update customer profile
  Future<void> updateCustomerProfile(String customerId, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', customerId);
  }

  // ================== SESSION TRACKING ==================

  /// Log app session
  Future<String> logAppSession({
    required String customerId,
    required String appVersion,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final response = await _client
        .from('customer_app_sessions')
        .insert({
          'customer_id': customerId,
          'app_version': appVersion,
          'device_info': deviceInfo ?? {},
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// End app session
  Future<void> endAppSession(String sessionId) async {
    await _client.from('customer_app_sessions').update({
      'logout_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }
}
