import 'package:equatable/equatable.dart';

class AuditLogModel extends Equatable {
  final String id;
  final String staffId;
  final String action;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic>? metadata;
  final double? gpsLat;
  final double? gpsLng;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  const AuditLogModel({
    required this.id,
    required this.staffId,
    required this.action,
    this.entityType,
    this.entityId,
    this.metadata,
    this.gpsLat,
    this.gpsLng,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] ?? '',
      staffId: json['staff_id'] ?? '',
      action: json['action'] ?? '',
      entityType: json['entity_type'],
      entityId: json['entity_id'],
      metadata: json['metadata'],
      gpsLat: (json['gps_lat'] as num?)?.toDouble(),
      gpsLng: (json['gps_lng'] as num?)?.toDouble(),
      ipAddress: json['ip_address'],
      userAgent: json['user_agent'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
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
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'created_at': createdAt.toIso8601String(),
    };
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
        ipAddress,
        userAgent,
        createdAt,
      ];
}

/// Audit action types
enum AuditAction {
  // Authentication
  login,
  logout,
  loginFailed,

  // Collections
  collectionCreated,
  collectionUpdated,
  collectionDeleted,
  collectionSynced,

  // Visits
  visitCheckIn,
  visitCheckOut,

  // Wallet
  walletDeposit,
  walletWithdraw,

  // Breaks
  breakStart,
  breakEnd,

  // Profile
  profileUpdated,
  passwordChanged,
  pinChanged,

  // Location
  locationUpdated,
  gpsTrackingStarted,
  gpsTrackingStopped,

  // Sync
  syncStarted,
  syncCompleted,
  syncFailed,

  // Admin
  approvalGranted,
  approvalRejected,
  targetSet,
  branchChanged,
}

/// Audit action descriptions
extension AuditActionExtension on AuditAction {
  String get description {
    switch (this) {
      case AuditAction.login:
        return 'User logged in';
      case AuditAction.logout:
        return 'User logged out';
      case AuditAction.loginFailed:
        return 'Login attempt failed';
      case AuditAction.collectionCreated:
        return 'Collection recorded';
      case AuditAction.collectionUpdated:
        return 'Collection updated';
      case AuditAction.collectionDeleted:
        return 'Collection deleted';
      case AuditAction.collectionSynced:
        return 'Collection synced to server';
      case AuditAction.visitCheckIn:
        return 'Visit check-in';
      case AuditAction.visitCheckOut:
        return 'Visit check-out';
      case AuditAction.walletDeposit:
        return 'Cash deposited';
      case AuditAction.walletWithdraw:
        return 'Cash withdrawn';
      case AuditAction.breakStart:
        return 'Break started';
      case AuditAction.breakEnd:
        return 'Break ended';
      case AuditAction.profileUpdated:
        return 'Profile updated';
      case AuditAction.passwordChanged:
        return 'Password changed';
      case AuditAction.pinChanged:
        return 'PIN changed';
      case AuditAction.locationUpdated:
        return 'Location updated';
      case AuditAction.gpsTrackingStarted:
        return 'GPS tracking started';
      case AuditAction.gpsTrackingStopped:
        return 'GPS tracking stopped';
      case AuditAction.syncStarted:
        return 'Sync started';
      case AuditAction.syncCompleted:
        return 'Sync completed';
      case AuditAction.syncFailed:
        return 'Sync failed';
      case AuditAction.approvalGranted:
        return 'Approval granted';
      case AuditAction.approvalRejected:
        return 'Approval rejected';
      case AuditAction.targetSet:
        return 'Target set';
      case AuditAction.branchChanged:
        return 'Branch changed';
    }
  }

  String get category {
    switch (this) {
      case AuditAction.login:
      case AuditAction.logout:
      case AuditAction.loginFailed:
        return 'Authentication';
      case AuditAction.collectionCreated:
      case AuditAction.collectionUpdated:
      case AuditAction.collectionDeleted:
      case AuditAction.collectionSynced:
        return 'Collections';
      case AuditAction.visitCheckIn:
      case AuditAction.visitCheckOut:
        return 'Visits';
      case AuditAction.walletDeposit:
      case AuditAction.walletWithdraw:
        return 'Wallet';
      case AuditAction.breakStart:
      case AuditAction.breakEnd:
        return 'Breaks';
      case AuditAction.profileUpdated:
      case AuditAction.passwordChanged:
      case AuditAction.pinChanged:
        return 'Profile';
      case AuditAction.locationUpdated:
      case AuditAction.gpsTrackingStarted:
      case AuditAction.gpsTrackingStopped:
        return 'Location';
      case AuditAction.syncStarted:
      case AuditAction.syncCompleted:
      case AuditAction.syncFailed:
        return 'Sync';
      case AuditAction.approvalGranted:
      case AuditAction.approvalRejected:
      case AuditAction.targetSet:
      case AuditAction.branchChanged:
        return 'Admin';
    }
  }
}
