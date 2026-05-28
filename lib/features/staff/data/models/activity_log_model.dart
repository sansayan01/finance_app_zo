import 'package:equatable/equatable.dart';
import '../services/offline_sync_engine.dart';

class ActivityLogModel extends Equatable {
  final String id;
  final String? staffId;

  // Action details
  final String action;
  final String? entityType;
  final String? entityId;

  // Metadata (flexible JSON)
  final Map<String, dynamic> metadata;

  // GPS Location
  final double? gpsLat;
  final double? gpsLng;
  final String? gpsAddress;

  // Device info
  final String? deviceId;
  final String? appVersion;
  final String? platform;

  // Sync
  final SyncStatus syncStatus;

  // Timestamps
  final DateTime createdAt;

  const ActivityLogModel({
    required this.id,
    this.staffId,
    required this.action,
    this.entityType,
    this.entityId,
    this.metadata = const {},
    this.gpsLat,
    this.gpsLng,
    this.gpsAddress,
    this.deviceId,
    this.appVersion,
    this.platform,
    this.syncStatus = SyncStatus.synced,
    required this.createdAt,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    return ActivityLogModel(
      id: json['id'] as String,
      staffId: json['staff_id'] as String?,
      action: json['action'] as String,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      gpsLat: (json['gps_lat'] as num?)?.toDouble(),
      gpsLng: (json['gps_lng'] as num?)?.toDouble(),
      gpsAddress: json['gps_address'] as String?,
      deviceId: json['device_id'] as String?,
      appVersion: json['app_version'] as String?,
      platform: json['platform'] as String?,
      syncStatus: _parseSyncStatus(json['sync_status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_id': staffId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'metadata': metadata,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'gps_address': gpsAddress,
      'device_id': deviceId,
      'app_version': appVersion,
      'platform': platform,
      'sync_status': syncStatus.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseInsert() {
    return {
      'staff_id': staffId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'metadata': metadata,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'gps_address': gpsAddress,
      'device_id': deviceId,
      'app_version': appVersion,
      'platform': platform,
      'sync_status': 'synced',
    };
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

  bool get hasLocation => gpsLat != null && gpsLng != null;
  bool get isPendingSync => syncStatus == SyncStatus.pending;

  ActivityLogModel copyWith({
    String? id,
    String? staffId,
    String? action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
    double? gpsLat,
    double? gpsLng,
    String? gpsAddress,
    String? deviceId,
    String? appVersion,
    String? platform,
    SyncStatus? syncStatus,
    DateTime? createdAt,
  }) {
    return ActivityLogModel(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      metadata: metadata ?? this.metadata,
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      gpsAddress: gpsAddress ?? this.gpsAddress,
      deviceId: deviceId ?? this.deviceId,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        staffId,
        action,
        entityType,
        entityId,
        metadata,
        gpsLat,
        gpsLng,
        gpsAddress,
        deviceId,
        appVersion,
        platform,
        syncStatus,
        createdAt,
      ];
}

// Activity action constants
class ActivityAction {
  static const String login = 'login';
  static const String logout = 'logout';
  static const String collectionRecorded = 'collection_recorded';
  static const String collectionSynced = 'collection_synced';
  static const String visitCheckin = 'visit_checkin';
  static const String visitCheckout = 'visit_checkout';
  static const String depositRecorded = 'deposit_recorded';
  static const String targetAchieved = 'target_achieved';
  static const String streakExtended = 'streak_extended';
  static const String streakBroken = 'streak_broken';
  static const String locationUpdated = 'location_updated';
  static const String syncFailed = 'sync_failed';
  static const String syncRetry = 'sync_retry';
  static const String appOpened = 'app_opened';
  static const String appBackgrounded = 'app_backgrounded';
}

class EntityType {
  static const String collection = 'collection';
  static const String member = 'member';
  static const String loan = 'loan';
  static const String savings = 'savings';
  static const String deposit = 'deposit';
  static const String target = 'target';
  static const String streak = 'streak';
}
