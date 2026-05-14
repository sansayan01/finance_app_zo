import 'package:equatable/equatable.dart';

enum NotificationType {
  paymentDue,
  collectionVisit,
  loanApproved,
  savingsUpdate,
  emiReminder,
  kycUpdate,
  general,
}

enum PaymentRequestStatus {
  pending,
  approved,
  rejected,
  completed,
}

enum TicketStatus {
  open,
  inProgress,
  resolved,
  closed,
}

enum TicketPriority {
  low,
  normal,
  high,
  urgent,
}

class CustomerNotification extends Equatable {
  final String id;
  final String customerId;
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? data;

  const CustomerNotification({
    required this.id,
    required this.customerId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.data,
  });

  factory CustomerNotification.fromJson(Map<String, dynamic> json) {
    NotificationType type = NotificationType.general;
    final typeString = json['type'] as String?;
    if (typeString != null) {
      switch (typeString) {
        case 'payment_due':
          type = NotificationType.paymentDue;
          break;
        case 'collection_visit':
          type = NotificationType.collectionVisit;
          break;
        case 'loan_approved':
          type = NotificationType.loanApproved;
          break;
        case 'savings_update':
          type = NotificationType.savingsUpdate;
          break;
        case 'emi_reminder':
          type = NotificationType.emiReminder;
          break;
        case 'kyc_update':
          type = NotificationType.kycUpdate;
          break;
      }
    }

    return CustomerNotification(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: type,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    String typeString = 'general';
    switch (type) {
      case NotificationType.paymentDue:
        typeString = 'payment_due';
        break;
      case NotificationType.collectionVisit:
        typeString = 'collection_visit';
        break;
      case NotificationType.loanApproved:
        typeString = 'loan_approved';
        break;
      case NotificationType.savingsUpdate:
        typeString = 'savings_update';
        break;
      case NotificationType.emiReminder:
        typeString = 'emi_reminder';
        break;
      case NotificationType.kycUpdate:
        typeString = 'kyc_update';
        break;
      default:
        typeString = 'general';
    }

    return {
      'id': id,
      'customer_id': customerId,
      'title': title,
      'message': message,
      'type': typeString,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'data': data,
    };
  }

  CustomerNotification copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return CustomerNotification(
      id: id,
      customerId: customerId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      data: data,
    );
  }

  @override
  List<Object?> get props => [id, customerId, title, message, type, isRead, createdAt, readAt, data];
}

class CustomerPaymentRequest extends Equatable {
  final String id;
  final String customerId;
  final String? loanId;
  final double amount;
  final String paymentMethod;
  final PaymentRequestStatus status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String? notes;

  const CustomerPaymentRequest({
    required this.id,
    required this.customerId,
    this.loanId,
    required this.amount,
    this.paymentMethod = 'cash',
    this.status = PaymentRequestStatus.pending,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
    this.notes,
  });

  factory CustomerPaymentRequest.fromJson(Map<String, dynamic> json) {
    PaymentRequestStatus status = PaymentRequestStatus.pending;
    final statusString = json['status'] as String?;
    if (statusString != null) {
      switch (statusString) {
        case 'approved':
          status = PaymentRequestStatus.approved;
          break;
        case 'rejected':
          status = PaymentRequestStatus.rejected;
          break;
        case 'completed':
          status = PaymentRequestStatus.completed;
          break;
        default:
          status = PaymentRequestStatus.pending;
      }
    }

    return CustomerPaymentRequest(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      loanId: json['loan_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      status: status,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
      processedBy: json['processed_by'] as String?,
      notes: json['notes'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, customerId, loanId, amount, paymentMethod, status, requestedAt, processedAt, processedBy, notes];
}

class CustomerSupportTicket extends Equatable {
  final String id;
  final String customerId;
  final String subject;
  final String message;
  final TicketStatus status;
  final TicketPriority priority;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  const CustomerSupportTicket({
    required this.id,
    required this.customerId,
    required this.subject,
    required this.message,
    this.status = TicketStatus.open,
    this.priority = TicketPriority.normal,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  factory CustomerSupportTicket.fromJson(Map<String, dynamic> json) {
    TicketStatus status = TicketStatus.open;
    final statusString = json['status'] as String?;
    if (statusString != null) {
      switch (statusString) {
        case 'in_progress':
          status = TicketStatus.inProgress;
          break;
        case 'resolved':
          status = TicketStatus.resolved;
          break;
        case 'closed':
          status = TicketStatus.closed;
          break;
        default:
          status = TicketStatus.open;
      }
    }

    TicketPriority priority = TicketPriority.normal;
    final priorityString = json['priority'] as String?;
    if (priorityString != null) {
      switch (priorityString) {
        case 'low':
          priority = TicketPriority.low;
          break;
        case 'high':
          priority = TicketPriority.high;
          break;
        case 'urgent':
          priority = TicketPriority.urgent;
          break;
        default:
          priority = TicketPriority.normal;
      }
    }

    return CustomerSupportTicket(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      subject: json['subject'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: status,
      priority: priority,
      assignedTo: json['assigned_to'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, customerId, subject, message, status, priority, assignedTo, createdAt, updatedAt, resolvedAt];
}

class CustomerFeedback extends Equatable {
  final String id;
  final String customerId;
  final String type;
  final String? subject;
  final String message;
  final int? rating;
  final String status;
  final DateTime createdAt;

  const CustomerFeedback({
    required this.id,
    required this.customerId,
    required this.type,
    this.subject,
    required this.message,
    this.rating,
    this.status = 'new',
    required this.createdAt,
  });

  factory CustomerFeedback.fromJson(Map<String, dynamic> json) {
    return CustomerFeedback(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      type: json['type'] as String? ?? 'other',
      subject: json['subject'] as String?,
      message: json['message'] as String? ?? '',
      rating: json['rating'] as int?,
      status: json['status'] as String? ?? 'new',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, customerId, type, subject, message, rating, status, createdAt];
}
