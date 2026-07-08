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
  final String? fatherName;
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
    this.fatherName,
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
      fatherName: (json['father_name'] ?? json['fatherName'])?.toString(),
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
      'father_name': fatherName,
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

/// Account status — mirrors `profiles.status` check constraint.
enum AccountStatus { active, inactive, suspended, onLeave, pending }

AccountStatus parseStatus(String? raw) {
  switch (raw?.toLowerCase().trim()) {
    case 'inactive':
      return AccountStatus.inactive;
    case 'suspended':
      return AccountStatus.suspended;
    case 'on_leave':
    case 'onleave':
      return AccountStatus.onLeave;
    case 'pending':
      return AccountStatus.pending;
    case 'active':
    default:
      return AccountStatus.active;
  }
}

extension AccountStatusX on AccountStatus {
  String get wireValue => switch (this) {
        AccountStatus.active => 'active',
        AccountStatus.inactive => 'inactive',
        AccountStatus.suspended => 'suspended',
        AccountStatus.onLeave => 'on_leave',
        AccountStatus.pending => 'pending',
      };

  String get label => switch (this) {
        AccountStatus.active => 'Active',
        AccountStatus.inactive => 'Inactive',
        AccountStatus.suspended => 'Suspended',
        AccountStatus.onLeave => 'On Leave',
        AccountStatus.pending => 'Pending',
      };
}

class ProfileModel {
  final String id;
  final String? userId;
  final String? fullName;
  final String? phone;
  final String? fatherName;
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
  final String? avatarUrl;
  final String? memberCode; // member_id on profiles / member_id on members
  final String? staffCode;
  final AccountStatus status;
  final bool isOnDuty;
  final DateTime? lastSeenAt;
  final DateTime? dateOfBirth;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// `true` when this row was sourced from the `members` table rather than
  /// the `profiles` table. Members do not have an `auth.users` link, status
  /// column or role; treat them as customers in the UI.
  final bool isMember;

  ProfileModel({
    required this.id,
    this.userId,
    this.fullName,
    this.phone,
    this.fatherName,
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
    this.avatarUrl,
    this.memberCode,
    this.staffCode,
    this.status = AccountStatus.active,
    this.isOnDuty = false,
    this.lastSeenAt,
    this.dateOfBirth,
    this.createdAt,
    this.updatedAt,
    this.isMember = false,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      fullName: (json['full_name'] ?? json['fullName'])?.toString(),
      phone: json['phone']?.toString(),
      fatherName: json['father_name']?.toString(),
      pan: json['pan']?.toString(),
      aadhar: json['aadhar']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString(),
      role: parseRole(json['role']?.toString() ?? 'customer'),
      orgId: json['org_id']?.toString(),
      branchId: json['branch_id']?.toString(),
      branchName:
          json['branch'] is Map ? json['branch']['name']?.toString() : null,
      employeeId: json['employee_id']?.toString(),
      assignedZone: json['assigned_zone']?.toString(),
      email: json['email']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      memberCode: json['member_id']?.toString(),
      staffCode: json['staff_code']?.toString(),
      status: parseStatus(json['status']?.toString()),
      isOnDuty: json['is_on_duty'] as bool? ?? false,
      lastSeenAt: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'].toString())
          : null,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      isMember: false,
    );
  }

  /// Build a ProfileModel from a row of the `members` table (customer view).
  factory ProfileModel.fromMembersJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      fullName: (json['full_name'] ?? json['name'])?.toString(),
      phone: json['phone']?.toString(),
      fatherName: json['father_name']?.toString(),
      pan: json['pan']?.toString(),
      aadhar: json['aadhar']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString(),
      role: UserRole.customer,
      orgId: json['org_id']?.toString(),
      branchId: json['branch_id']?.toString(),
      branchName:
          json['branch'] is Map ? json['branch']['name']?.toString() : null,
      email: json['email']?.toString(),
      avatarUrl: (json['profile_photo_url'] ?? json['shop_photo_url'])?.toString(),
      memberCode: json['member_id']?.toString(),
      staffCode: json['staff_code']?.toString(),
      status: parseStatus(json['status']?.toString()),
      isOnDuty: json['is_on_duty'] as bool? ?? false,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      isMember: true,
    );
  }

  ProfileModel copyWith({
    String? fullName,
    String? phone,
    String? email,
    UserRole? role,
    String? branchId,
    String? branchName,
    AccountStatus? status,
    DateTime? lastSeenAt,
  }) {
    return ProfileModel(
      id: id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      pan: pan,
      aadhar: aadhar,
      address: address,
      city: city,
      state: state,
      pincode: pincode,
      role: role ?? this.role,
      orgId: orgId,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      employeeId: employeeId,
      assignedZone: assignedZone,
      email: email ?? this.email,
      avatarUrl: avatarUrl,
      memberCode: memberCode,
      staffCode: staffCode,
      status: status ?? this.status,
      isOnDuty: isOnDuty,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      dateOfBirth: dateOfBirth,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isMember: isMember,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'father_name': fatherName,
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
      'avatar_url': avatarUrl,
      'member_id': memberCode,
      'staff_code': staffCode,
      'status': status.wireValue,
      'is_on_duty': isOnDuty,
      'last_login': lastSeenAt?.toIso8601String(),
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
