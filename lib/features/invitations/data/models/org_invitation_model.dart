import '../../../../core/constants/enums.dart';

class OrgInvitationModel {
  final String id;
  final String orgId;
  final String? orgName;
  final String email;
  final UserRole role;
  final String? branchId;
  final String status;
  final String token;
  final String? invitedBy;
  final String? inviterName;
  final String? message;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;

  OrgInvitationModel({
    required this.id,
    required this.orgId,
    this.orgName,
    required this.email,
    required this.role,
    this.branchId,
    required this.status,
    required this.token,
    this.invitedBy,
    this.inviterName,
    this.message,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRevoked => status == 'revoked';
  bool get isExpired =>
      status == 'expired' || expiresAt.isBefore(DateTime.now());

  String get roleDisplay {
    return switch (role) {
      UserRole.superAdmin => 'Super Admin',
      UserRole.executiveAdmin => 'Executive Admin',
      UserRole.manager => 'Branch Manager',
      UserRole.collectionAgent => 'Collection Agent',
      UserRole.customer => 'Customer',
    };
  }

  String? get personalMessage => message;

  factory OrgInvitationModel.fromJson(Map<String, dynamic> json) {
    return OrgInvitationModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      orgName: json['org']?['name']?.toString(),
      email: json['email']?.toString() ?? '',
      role: _roleFromString(json['role']?.toString()),
      branchId: json['branch_id']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      token: json['token']?.toString() ?? '',
      invitedBy: json['invited_by']?.toString(),
      inviterName: json['inviter']?['full_name']?.toString(),
      message: json['message']?.toString(),
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      expiresAt: DateTime.parse(
          json['expires_at'] ?? DateTime.now().toIso8601String()),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
    );
  }

  static UserRole _roleFromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'superadmin':
        return UserRole.superAdmin;
      case 'executiveadmin':
        return UserRole.executiveAdmin;
      case 'manager':
        return UserRole.manager;
      case 'collectionagent':
      case 'fieldstaff':
        return UserRole.collectionAgent;
      case 'customer':
      case 'retailmember':
        return UserRole.customer;
      default:
        return UserRole.collectionAgent;
    }
  }
}
