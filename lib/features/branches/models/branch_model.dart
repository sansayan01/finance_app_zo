import 'package:equatable/equatable.dart';

class BranchModel extends Equatable {
  final String id;
  final String orgId;
  final String name;
  final String code;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? phone;
  final String? email;
  final String? managerId;
  final String? managerName;
  final String status;
  final double? locationLat;
  final double? locationLng;
  final Map<String, dynamic>? operatingHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BranchModel({
    required this.id,
    required this.orgId,
    required this.name,
    required this.code,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.phone,
    this.email,
    this.managerId,
    this.managerName,
    required this.status,
    this.locationLat,
    this.locationLng,
    this.operatingHours,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      managerId: json['manager_id'] as String?,
      managerName: json['manager']?['full_name'] as String?,
      status: json['status'] as String? ?? 'active',
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      operatingHours: json['operating_hours'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'org_id': orgId,
      'name': name,
      'code': code,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'phone': phone,
      'email': email,
      'manager_id': managerId,
      'status': status,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'operating_hours': operatingHours,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BranchModel copyWith({
    String? name,
    String? code,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? phone,
    String? email,
    String? managerId,
    String? status,
    double? locationLat,
    double? locationLng,
    Map<String, dynamic>? operatingHours,
  }) {
    return BranchModel(
      id: id,
      orgId: orgId,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      managerId: managerId ?? this.managerId,
      managerName: managerName,
      status: status ?? this.status,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      operatingHours: operatingHours ?? this.operatingHours,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  bool get isActive => status == 'active';
  String get displayName => '$name ($code)';

  @override
  List<Object?> get props => [
        id,
        orgId,
        name,
        code,
        address,
        city,
        state,
        pincode,
        phone,
        email,
        managerId,
        managerName,
        status,
        locationLat,
        locationLng,
        operatingHours,
        createdAt,
        updatedAt,
      ];
}

class BranchStats extends Equatable {
  final int totalStaff;
  final int totalMembers;
  final int totalLoans;
  final double totalSavings;
  final double activeLoans;

  const BranchStats({
    this.totalStaff = 0,
    this.totalMembers = 0,
    this.totalLoans = 0,
    this.totalSavings = 0,
    this.activeLoans = 0,
  });

  factory BranchStats.fromJson(Map<String, dynamic> json) {
    return BranchStats(
      totalStaff: (json['total_staff'] as num?)?.toInt() ?? 0,
      totalMembers: (json['total_members'] as num?)?.toInt() ?? 0,
      totalLoans: (json['total_loans'] as num?)?.toInt() ?? 0,
      totalSavings: (json['total_savings'] as num?)?.toDouble() ?? 0,
      activeLoans: (json['active_loans'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [totalStaff, totalMembers, totalLoans, totalSavings, activeLoans];
}
