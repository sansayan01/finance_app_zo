import 'package:equatable/equatable.dart';
import '../services/offline_sync_engine.dart';

enum ActivityType {
  idle,
  traveling,
  collecting,
  resting,
}

class StaffLocationModel extends Equatable {
  final String id;
  final String staffId;

  // Location
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;

  // Context
  final ActivityType activityType;
  final int? batteryLevel;
  final bool isCharging;

  // Timestamps
  final DateTime recordedAt;

  // Sync
  final SyncStatus syncStatus;
  final DateTime createdAt;

  const StaffLocationModel({
    required this.id,
    required this.staffId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.activityType = ActivityType.idle,
    this.batteryLevel,
    this.isCharging = false,
    required this.recordedAt,
    this.syncStatus = SyncStatus.synced,
    required this.createdAt,
  });

  factory StaffLocationModel.fromJson(Map<String, dynamic> json) {
    return StaffLocationModel(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      activityType: _parseActivityType(json['activity_type'] as String?),
      batteryLevel: json['battery_level'] as int?,
      isCharging: json['is_charging'] as bool? ?? false,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      syncStatus: _parseSyncStatus(json['sync_status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_id': staffId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'activity_type': activityType.name,
      'battery_level': batteryLevel,
      'is_charging': isCharging,
      'recorded_at': recordedAt.toIso8601String(),
      'sync_status': syncStatus.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseInsert() {
    return {
      'staff_id': staffId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'activity_type': activityType.name,
      'battery_level': batteryLevel,
      'is_charging': isCharging,
      'recorded_at': recordedAt.toIso8601String(),
      'sync_status': 'synced',
    };
  }

  static ActivityType _parseActivityType(String? value) {
    switch (value) {
      case 'idle':
        return ActivityType.idle;
      case 'traveling':
        return ActivityType.traveling;
      case 'collecting':
        return ActivityType.collecting;
      case 'resting':
        return ActivityType.resting;
      default:
        return ActivityType.idle;
    }
  }

  static SyncStatus _parseSyncStatus(String? value) {
    switch (value) {
      case 'pending':
        return SyncStatus.pending;
      case 'synced':
        return SyncStatus.synced;
      case 'failed':
        return SyncStatus.failed;
      default:
        return SyncStatus.synced;
    }
  }

  bool get hasAccuracy => accuracy != null && accuracy! <= 100;
  bool get isPendingSync => syncStatus == SyncStatus.pending;

  bool get isLowBattery => batteryLevel != null && batteryLevel! < 20;

  StaffLocationModel copyWith({
    String? id,
    String? staffId,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    ActivityType? activityType,
    int? batteryLevel,
    bool? isCharging,
    DateTime? recordedAt,
    SyncStatus? syncStatus,
    DateTime? createdAt,
  }) {
    return StaffLocationModel(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      activityType: activityType ?? this.activityType,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      recordedAt: recordedAt ?? this.recordedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        staffId,
        latitude,
        longitude,
        accuracy,
        altitude,
        speed,
        heading,
        activityType,
        batteryLevel,
        isCharging,
        recordedAt,
        syncStatus,
        createdAt,
      ];
}
