import 'package:equatable/equatable.dart';

enum StaffRole {
  collector,
  supervisor,
  branchManager,
  areaManager;

  String get displayName {
    switch (this) {
      case StaffRole.collector:
        return 'Collection Agent';
      case StaffRole.supervisor:
        return 'Supervisor';
      case StaffRole.branchManager:
        return 'Branch Manager';
      case StaffRole.areaManager:
        return 'Area Manager';
    }
  }

  /// Maps to the DB constraint values on collections.collected_by_role
  String get dbValue {
    switch (this) {
      case StaffRole.collector:
        return 'collectionAgent';
      case StaffRole.supervisor:
        return 'manager';
      case StaffRole.branchManager:
        return 'manager';
      case StaffRole.areaManager:
        return 'manager';
    }
  }

  /// Maps to the DB constraint values on staff_profiles.role
  String get dbRole {
    switch (this) {
      case StaffRole.collector:
        return 'collector';
      case StaffRole.supervisor:
        return 'supervisor';
      case StaffRole.branchManager:
        return 'branch_manager';
      case StaffRole.areaManager:
        return 'area_manager';
    }
  }
}

enum StaffStatus {
  active,
  inactive,
  suspended,
  onLeave;

  String get dbValue {
    switch (this) {
      case StaffStatus.active:
        return 'active';
      case StaffStatus.inactive:
        return 'inactive';
      case StaffStatus.suspended:
        return 'suspended';
      case StaffStatus.onLeave:
        return 'on_leave';
    }
  }
}

enum ShiftType {
  morning,
  evening,
  fullDay;

  String get displayName {
    switch (this) {
      case ShiftType.morning:
        return 'Morning';
      case ShiftType.evening:
        return 'Evening';
      case ShiftType.fullDay:
        return 'Full Day';
    }
  }

  String get dbValue {
    switch (this) {
      case ShiftType.morning:
        return 'morning';
      case ShiftType.evening:
        return 'evening';
      case ShiftType.fullDay:
        return 'full_day';
    }
  }
}

class StaffProfileModel extends Equatable {
  final String id;
  final String? orgId;
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
    this.orgId,
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
    // staff_code may come as 'staff_code' (profiles) or 'employee_id' (staff_profiles)
    final rawStaffCode = json['staff_code'] as String? ??
        json['employee_id'] as String? ??
        '';
    // role may come as 'role' or 'designation'
    final rawRole = json['role'] as String? ?? json['designation'] as String?;
    // hire_date may come as 'hire_date' or 'date_of_joining'
    final rawHireDate = json['hire_date'] as String? ??
        json['date_of_joining'] as String?;
    // assigned_areas may be a list or a single 'area' string
    final rawAreas = json['assigned_areas'] as List<dynamic>?;
    final rawArea = json['area'] as String?;

    return StaffProfileModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String?,
      userId: json['user_id'] as String?,
      staffCode: rawStaffCode,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      role: _parseRole(rawRole),
      branchId: json['branch_id'] as String?,
      branchName: json['branches']?['name'] as String?,
      status: _parseStatus(json['status'] as String?),
      assignedAreas: rawAreas?.map((e) => e.toString()).toList() ??
          (rawArea != null ? [rawArea] : []),
      shift: _parseShift(json['shift'] as String?),
      hireDate: rawHireDate != null
          ? DateTime.tryParse(rawHireDate)
          : null,
      dailyCollectionTarget:
          (json['daily_collection_target'] as num?)?.toDouble() ?? 50000.0,
      monthlyCollectionTarget:
          (json['monthly_collection_target'] as num?)?.toDouble() ?? 1500000.0,
      supervisorId: json['supervisor_id'] as String?,
      supervisorName: json['supervisor']?['full_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'org_id': orgId,
      'user_id': userId,
      'staff_code': staffCode,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'role': role.dbRole,
      'branch_id': branchId,
      'status': status.dbValue,
      'assigned_areas': assignedAreas,
      'shift': shift.dbValue,
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
    String? orgId,
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
      orgId: orgId ?? this.orgId,
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
        orgId,
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
