import '../../../../core/constants/enums.dart';
export '../../../../core/constants/enums.dart';

UserRole parseRole(String roleStr) {
  final normalized = roleStr.toLowerCase().trim();

  if (normalized.contains('superadmin') || normalized == 'owner') {
    return UserRole.superAdmin;
  }
  if (normalized.contains('admin') || normalized == 'executive') {
    return UserRole.executiveAdmin;
  }
  if (normalized.contains('manager') || normalized == 'supervisor') {
    return UserRole.manager;
  }
  if (normalized.contains('agent') ||
      normalized == 'staff' ||
      normalized == 'collector' ||
      normalized == 'fieldstaff' ||
      normalized == 'collectionagent') {
    return UserRole.collectionAgent;
  }
  
  // Default to customer for everything else
  return UserRole.customer;
}

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final UserRole? role;
  final String? avatarUrl;
  final String? orgId;
  final String? branchId;
  final String? memberId;
  final DateTime? createdAt;
  final bool is2FAEnabled;
  final bool isActive;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.role,
    this.avatarUrl,
    this.orgId,
    this.branchId,
    this.memberId,
    this.createdAt,
    this.is2FAEnabled = false,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName:
          json['full_name'] as String? ?? json['fullName'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      orgId: json['org_id'] as String?,
      branchId: json['branch_id'] as String?,
      memberId: json['member_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      role: parseRole(json['role']?.toString() ?? 'customer'),
      is2FAEnabled: json['is_2fa_enabled'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role?.name,
      'avatar_url': avatarUrl,
      'org_id': orgId,
      'branch_id': branchId,
      'member_id': memberId,
      'created_at': createdAt?.toIso8601String(),
      'is_2fa_enabled': is2FAEnabled,
      'is_active': isActive,
    };
  }
}

class ProfileModel {
  final String id;
  final String? userId;
  final String? fullName;
  final String? phone;
  final String? pan;
  final String? aadhar;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final UserRole? role;
  final String? orgId;
  final String? branchId;
  final String? branchName;
  final String? employeeId;
  final String? assignedZone;
  final DateTime? dateOfBirth;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProfileModel({
    required this.id,
    this.userId,
    this.fullName,
    this.phone,
    this.pan,
    this.aadhar,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.role,
    this.orgId,
    this.branchId,
    this.branchName,
    this.employeeId,
    this.assignedZone,
    this.email,
    this.dateOfBirth,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      fullName: (json['full_name'] ?? json['fullName'])?.toString(),
      phone: json['phone']?.toString(),
      pan: json['pan']?.toString(),
      aadhar: json['aadhar']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString(),
      role: parseRole(json['role']?.toString() ?? 'customer'),
      orgId: json['org_id']?.toString(),
      branchId: json['branch_id']?.toString(),
      branchName: json['branch'] is Map ? json['branch']['name']?.toString() : null,
      employeeId: json['employee_id']?.toString(),
      assignedZone: json['assigned_zone']?.toString(),
      email: json['email']?.toString(),
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'phone': phone,
      'pan': pan,
      'aadhar': aadhar,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'role': role?.name,
      'org_id': orgId,
      'branch_id': branchId,
      'employee_id': employeeId,
      'assigned_zone': assignedZone,
      'email': email,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
