class CustomerTicketModel {
  final String id;
  final String subject;
  final String message;
  final String status;
  final String priority;
  final String? assignedTo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  CustomerTicketModel({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
  });

  factory CustomerTicketModel.fromJson(Map<String, dynamic> json) {
    return CustomerTicketModel(
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
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
    );
  }

  bool get isOpen => status == 'open';
  bool get isResolved => status == 'resolved' || status == 'closed';
}

class CustomerTicketMessageModel {
  final String id;
  final String ticketId;
  final String senderId;
  final String message;
  final DateTime? createdAt;

  CustomerTicketMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.message,
    this.createdAt,
  });

  factory CustomerTicketMessageModel.fromJson(Map<String, dynamic> json) {
    return CustomerTicketMessageModel(
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
