import 'package:equatable/equatable.dart';

/// Audit log model
class AuditLogModel extends Equatable {
  final String id;
  final String orgId;

  // Who
  final String? userId;
  final String? userEmail;
  final String? userName;

  // What
  final String action;
  final String entityType;
  final String? entityId;

  // Details
  final String? description;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;

  // Where
  final String? ipAddress;
  final String? userAgent;
  final String? deviceType;

  // When
  final DateTime createdAt;

  // Classification
  final String severity;
  final String? category;

  const AuditLogModel({
    required this.id,
    required this.orgId,
    this.userId,
    this.userEmail,
    this.userName,
    required this.action,
    required this.entityType,
    this.entityId,
    this.description,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    this.userAgent,
    this.deviceType,
    required this.createdAt,
    this.severity = 'info',
    this.category,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      userId: json['user_id'] as String?,
      userEmail: json['user_email'] as String?,
      userName: json['user_name'] as String?,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      description: json['description'] as String?,
      oldValues: json['old_values'] as Map<String, dynamic>?,
      newValues: json['new_values'] as Map<String, dynamic>?,
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent'] as String?,
      deviceType: json['device_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      severity: json['severity'] as String? ?? 'info',
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'org_id': orgId,
      'user_id': userId,
      'user_email': userEmail,
      'user_name': userName,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'description': description,
      'old_values': oldValues,
      'new_values': newValues,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'device_type': deviceType,
      'created_at': createdAt.toIso8601String(),
      'severity': severity,
      'category': category,
    };
  }

  @override
  List<Object?> get props => [
        id,
        orgId,
        userId,
        userEmail,
        userName,
        action,
        entityType,
        entityId,
        description,
        oldValues,
        newValues,
        ipAddress,
        userAgent,
        deviceType,
        createdAt,
        severity,
        category,
      ];
}

/// Support ticket model
class SupportTicketModel extends Equatable {
  final String id;
  final String orgId;
  final String ticketNumber;
  final String subject;
  final String description;
  final String priority;
  final String status;
  final String? assignedTo;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? firstResponseAt;
  final DateTime? resolvedAt;
  final bool slaBreached;

  const SupportTicketModel({
    required this.id,
    required this.orgId,
    required this.ticketNumber,
    required this.subject,
    required this.description,
    this.priority = 'normal',
    this.status = 'open',
    this.assignedTo,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    this.firstResponseAt,
    this.resolvedAt,
    this.slaBreached = false,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      ticketNumber: json['ticket_number'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String,
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'open',
      assignedTo: json['assigned_to'] as String?,
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      firstResponseAt: json['first_response_at'] != null
          ? DateTime.parse(json['first_response_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      slaBreached: json['sla_breached'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'org_id': orgId,
      'ticket_number': ticketNumber,
      'subject': subject,
      'description': description,
      'priority': priority,
      'status': status,
      'assigned_to': assignedTo,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'first_response_at': firstResponseAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'sla_breached': slaBreached,
    };
  }

  @override
  List<Object?> get props => [
        id,
        orgId,
        ticketNumber,
        subject,
        description,
        priority,
        status,
        assignedTo,
        category,
        createdAt,
        updatedAt,
        firstResponseAt,
        resolvedAt,
        slaBreached,
      ];
}
