import 'package:equatable/equatable.dart';

enum StaffRole {
  collector,
  supervisor,
  branchManager,
  areaManager,
}

enum StaffStatus {
  active,
  inactive,
  suspended,
  onLeave,
}

enum ShiftType {
  morning,
  evening,
  fullDay,
}

class StaffProfileModel extends Equatable {
  final String id;
  final String? userId;
  final String staffCode;
  final String fullName;
  final String phone;
  final String? email;
  final StaffRole role;
  final String? branchId;
  final String? branchName;
  final StaffStatus status;
  final List<String> assignedAreas;
  final ShiftType shift;
  final DateTime? hireDate;
  final double dailyCollectionTarget;
  final double monthlyCollectionTarget;
  final String? supervisorId;
  final String? supervisorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StaffProfileModel({
    required this.id,
    this.userId,
    required this.staffCode,
    required this.fullName,
    required this.phone,
    this.email,
    this.role = StaffRole.collector,
    this.branchId,
    this.branchName,
    this.status = StaffStatus.active,
    this.assignedAreas = const [],
    this.shift = ShiftType.morning,
    this.hireDate,
    this.dailyCollectionTarget = 50000.0,
    this.monthlyCollectionTarget = 1500000.0,
    this.supervisorId,
    this.supervisorName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StaffProfileModel.fromJson(Map<String, dynamic> json) {
    return StaffProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      staffCode: json['staff_code'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      role: _parseRole(json['role'] as String?),
      branchId: json['branch_id'] as String?,
      branchName: json['branches']?['name'] as String?,
      status: _parseStatus(json['status'] as String?),
      assignedAreas: (json['assigned_areas'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      shift: _parseShift(json['shift'] as String?),
      hireDate: json['hire_date'] != null
          ? DateTime.parse(json['hire_date'] as String)
          : null,
      dailyCollectionTarget:
          (json['daily_collection_target'] as num?)?.toDouble() ?? 50000.0,
      monthlyCollectionTarget:
          (json['monthly_collection_target'] as num?)?.toDouble() ?? 1500000.0,
      supervisorId: json['supervisor_id'] as String?,
      supervisorName: json['supervisor']?['full_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'staff_code': staffCode,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'role': role.name,
      'branch_id': branchId,
      'status': status.name,
      'assigned_areas': assignedAreas,
      'shift': shift.name,
      'hire_date': hireDate?.toIso8601String(),
      'daily_collection_target': dailyCollectionTarget,
      'monthly_collection_target': monthlyCollectionTarget,
      'supervisor_id': supervisorId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static StaffRole _parseRole(String? value) {
    switch (value) {
      case 'collector':
        return StaffRole.collector;
      case 'supervisor':
        return StaffRole.supervisor;
      case 'branch_manager':
        return StaffRole.branchManager;
      case 'area_manager':
        return StaffRole.areaManager;
      default:
        return StaffRole.collector;
    }
  }

  static StaffStatus _parseStatus(String? value) {
    switch (value) {
      case 'active':
        return StaffStatus.active;
      case 'inactive':
        return StaffStatus.inactive;
      case 'suspended':
        return StaffStatus.suspended;
      case 'on_leave':
        return StaffStatus.onLeave;
      default:
        return StaffStatus.active;
    }
  }

  static ShiftType _parseShift(String? value) {
    switch (value) {
      case 'morning':
        return ShiftType.morning;
      case 'evening':
        return ShiftType.evening;
      case 'full_day':
        return ShiftType.fullDay;
      default:
        return ShiftType.morning;
    }
  }

  bool get isActive => status == StaffStatus.active;
  bool get isCollector => role == StaffRole.collector;
  bool get isSupervisor => role == StaffRole.supervisor;
  bool get isManager =>
      role == StaffRole.branchManager || role == StaffRole.areaManager;

  StaffProfileModel copyWith({
    String? id,
    String? userId,
    String? staffCode,
    String? fullName,
    String? phone,
    String? email,
    StaffRole? role,
    String? branchId,
    String? branchName,
    StaffStatus? status,
    List<String>? assignedAreas,
    ShiftType? shift,
    DateTime? hireDate,
    double? dailyCollectionTarget,
    double? monthlyCollectionTarget,
    String? supervisorId,
    String? supervisorName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      staffCode: staffCode ?? this.staffCode,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      status: status ?? this.status,
      assignedAreas: assignedAreas ?? this.assignedAreas,
      shift: shift ?? this.shift,
      hireDate: hireDate ?? this.hireDate,
      dailyCollectionTarget:
          dailyCollectionTarget ?? this.dailyCollectionTarget,
      monthlyCollectionTarget:
          monthlyCollectionTarget ?? this.monthlyCollectionTarget,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        staffCode,
        fullName,
        phone,
        email,
        role,
        branchId,
        branchName,
        status,
        assignedAreas,
        shift,
        hireDate,
        dailyCollectionTarget,
        monthlyCollectionTarget,
        supervisorId,
        supervisorName,
        createdAt,
        updatedAt,
      ];
}
