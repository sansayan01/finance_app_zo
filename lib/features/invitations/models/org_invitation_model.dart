import 'package:equatable/equatable.dart';

enum InvitationRole {
  admin,
  manager,
  fieldStaff,
  accountant,
}

enum InvitationStatus {
  pending,
  accepted,
  expired,
  revoked,
}

class OrgInvitationModel extends Equatable {
  final String id;
  final String orgId;
  final String email;
  final InvitationRole role;
  final String? branchId;
  final String? invitedBy;
  final String? personalMessage;
  final InvitationStatus status;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final DateTime createdAt;

  const OrgInvitationModel({
    required this.id,
    required this.orgId,
    required this.email,
    required this.role,
    this.branchId,
    this.invitedBy,
    this.personalMessage,
    required this.status,
    required this.expiresAt,
    this.acceptedAt,
    this.acceptedBy,
    required this.createdAt,
  });

  bool get isPending => status == InvitationStatus.pending;
  bool get isExpired => status == InvitationStatus.expired || expiresAt.isBefore(DateTime.now());
  bool get isAccepted => status == InvitationStatus.accepted;
  bool get isRevoked => status == InvitationStatus.revoked;

  int get daysUntilExpiry {
    final remaining = expiresAt.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  String get roleDisplay {
    return switch (role) {
      InvitationRole.admin => 'Admin',
      InvitationRole.manager => 'Manager',
      InvitationRole.fieldStaff => 'Field Staff',
      InvitationRole.accountant => 'Accountant',
    };
  }

  String get statusDisplay {
    return switch (status) {
      InvitationStatus.pending => 'Pending',
      InvitationStatus.accepted => 'Accepted',
      InvitationStatus.expired => 'Expired',
      InvitationStatus.revoked => 'Revoked',
    };
  }

  factory OrgInvitationModel.fromJson(Map<String, dynamic> json) {
    InvitationRole parseRole(String? role) {
      return switch (role) {
        'admin' => InvitationRole.admin,
        'manager' => InvitationRole.manager,
        'fieldStaff' => InvitationRole.fieldStaff,
        'accountant' => InvitationRole.accountant,
        _ => InvitationRole.fieldStaff,
      };
    }

    InvitationStatus parseStatus(String? status) {
      return switch (status) {
        'pending' => InvitationStatus.pending,
        'accepted' => InvitationStatus.accepted,
        'expired' => InvitationStatus.expired,
        'revoked' => InvitationStatus.revoked,
        _ => InvitationStatus.pending,
      };
    }

    return OrgInvitationModel(
      id: json['id'] as String? ?? '',
      orgId: json['org_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: parseRole(json['role'] as String?),
      branchId: json['branch_id'] as String?,
      invitedBy: json['invited_by'] as String?,
      personalMessage: json['personal_message'] as String?,
      status: parseStatus(json['status'] as String?),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now(),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'] as String)
          : null,
      acceptedBy: json['accepted_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'org_id': orgId,
    'email': email,
    'role': role.name,
    'branch_id': branchId,
    'invited_by': invitedBy,
    'personal_message': personalMessage,
    'status': status.name,
    'expires_at': expiresAt.toIso8601String(),
    'accepted_at': acceptedAt?.toIso8601String(),
    'accepted_by': acceptedBy,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id, orgId, email, role, branchId, invitedBy, personalMessage,
    status, expiresAt, acceptedAt, acceptedBy, createdAt,
  ];
}
