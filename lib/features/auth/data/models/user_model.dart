import '../../../../core/constants/enums.dart';
export '../../../../core/constants/enums.dart';

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final UserRole? role;
  final String? avatarUrl;
  final String? orgId;
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
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
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
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final UserRole? role;
  final String? orgId;
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
    this.dateOfBirth,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      pan: json['pan'] as String?,
      aadhar: json['aadhar'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      role: json['role'] != null
          ? UserRole.values.firstWhere(
              (e) => e.name == json['role'],
              orElse: () => UserRole.retailMember,
            )
          : null,
      orgId: json['org_id'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
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
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
