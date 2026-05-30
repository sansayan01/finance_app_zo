import 'package:equatable/equatable.dart';
import 'package:microflow_pro/core/constants/enums.dart';

enum SyncState {
  pending,
  synced,
  failed,
}

class CollectionModel extends Equatable {
  final String id;
  final String? loanId;
  final String? loanScheduleId;
  final String? memberId;
  final String staffId;

  // Denormalized member info (for offline access)
  final String memberName;
  final String? memberPhone;
  final String? loanNumber;

  // Collection details
  final double amountExpected;
  final double amountCollected;
  double get variance => amountExpected - amountCollected;
  final bool isPartial;
  final bool isAdvance;

  // Payment details
  final PaymentMode paymentMode;
  final String? referenceNumber;

  // GPS Location (mandatory for audit)
  final double gpsLat;
  final double gpsLng;
  final double? gpsAccuracy;
  final String? gpsAddress;

  // Timestamps
  final DateTime collectionDate;
  final DateTime collectionTime;

  // Sync status (for offline-first)
  final SyncState syncStatus;
  final String? localId;
  final int syncAttempts;
  final DateTime? lastSyncAt;

  // Audit
  final String? remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CollectionModel({
    required this.id,
    this.loanId,
    this.loanScheduleId,
    this.memberId,
    required this.staffId,
    required this.memberName,
    this.memberPhone,
    this.loanNumber,
    required this.amountExpected,
    required this.amountCollected,
    this.isPartial = false,
    this.isAdvance = false,
    required this.paymentMode,
    this.referenceNumber,
    required this.gpsLat,
    required this.gpsLng,
    this.gpsAccuracy,
    this.gpsAddress,
    required this.collectionDate,
    required this.collectionTime,
    this.syncStatus = SyncState.synced,
    this.localId,
    this.syncAttempts = 0,
    this.lastSyncAt,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    return CollectionModel(
      id: json['id'] as String,
      loanId: json['loan_id'] as String?,
      loanScheduleId: json['loan_schedule_id'] as String?,
      memberId: json['member_id'] as String?,
      staffId: json['staff_id'] as String,
      memberName: json['member_name'] as String,
      memberPhone: json['member_phone'] as String?,
      loanNumber: json['loan_number'] as String?,
      amountExpected: (json['amount_expected'] as num).toDouble(),
      amountCollected: (json['amount_collected'] as num).toDouble(),
      isPartial: json['is_partial'] as bool? ?? false,
      isAdvance: json['is_advance'] as bool? ?? false,
      paymentMode: _parsePaymentMode(json['payment_mode'] as String?),
      referenceNumber: json['reference_number'] as String?,
      gpsLat: (json['gps_lat'] as num).toDouble(),
      gpsLng: (json['gps_lng'] as num).toDouble(),
      gpsAccuracy: (json['gps_accuracy'] as num?)?.toDouble(),
      gpsAddress: json['gps_address'] as String?,
      collectionDate: DateTime.parse(json['collection_date'] as String),
      collectionTime: _parseCollectionTime(json['collection_date'] as String?, json['collection_time']),
      syncStatus: _parseSyncState(json['sync_status'] as String?),
      localId: json['local_id'] as String?,
      syncAttempts: json['sync_attempts'] as int? ?? 0,
      lastSyncAt: json['last_sync_at'] != null
          ? DateTime.parse(json['last_sync_at'] as String)
          : null,
      remarks: json['remarks'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loan_id': loanId,
      'loan_schedule_id': loanScheduleId,
      'member_id': memberId,
      'staff_id': staffId,
      'member_name': memberName,
      'member_phone': memberPhone,
      'loan_number': loanNumber,
      'amount_expected': amountExpected,
      'amount_collected': amountCollected,
      'is_partial': isPartial,
      'is_advance': isAdvance,
      'payment_mode': _paymentModeToWire(paymentMode),
      'reference_number': referenceNumber,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'gps_accuracy': gpsAccuracy,
      'gps_address': gpsAddress,
      'collection_date': collectionDate.toIso8601String().split('T').first,
      'collection_time': '${collectionTime.hour.toString().padLeft(2, '0')}:${collectionTime.minute.toString().padLeft(2, '0')}:${collectionTime.second.toString().padLeft(2, '0')}',
      'sync_status': syncStatus.name,
      'local_id': localId,
      'sync_attempts': syncAttempts,
      'last_sync_at': lastSyncAt?.toIso8601String(),
      'remarks': remarks,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseInsert() {
    return {
      'loan_id': loanId,
      'loan_schedule_id': loanScheduleId,
      'member_id': memberId,
      'staff_id': staffId,
      'member_name': memberName,
      'member_phone': memberPhone,
      'loan_number': loanNumber,
      'amount_expected': amountExpected,
      'amount_collected': amountCollected,
      'is_partial': isPartial,
      'is_advance': isAdvance,
      'payment_mode': _paymentModeToWire(paymentMode),
      'reference_number': referenceNumber,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'gps_accuracy': gpsAccuracy,
      'gps_address': gpsAddress,
      'collection_date': collectionDate.toIso8601String().split('T').first,
      'collection_time': '${collectionTime.hour.toString().padLeft(2, '0')}:${collectionTime.minute.toString().padLeft(2, '0')}:${collectionTime.second.toString().padLeft(2, '0')}',
      'sync_status': 'synced',
      'local_id': localId,
      'remarks': remarks,
    };
  }

  static String _paymentModeToWire(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.cash:
        return 'cash';
      case PaymentMode.upi:
        return 'upi';
      case PaymentMode.bankTransfer:
        return 'bank_transfer';
      case PaymentMode.cheque:
        return 'cheque';
      case PaymentMode.card:
        return 'card';
    }
  }

  static PaymentMode _parsePaymentMode(String? value) {
    switch (value) {
      case 'cash':
        return PaymentMode.cash;
      case 'upi':
        return PaymentMode.upi;
      case 'bank_transfer':
        return PaymentMode.bankTransfer;
      case 'cheque':
        return PaymentMode.cheque;
      case 'card':
        return PaymentMode.card;
      default:
        return PaymentMode.cash;
    }
  }

  static DateTime _parseCollectionTime(String? dateStr, dynamic timeValue) {
    // time without time zone comes back as a bare string like "14:30:00"
    // which DateTime.parse cannot handle. Combine with date first.
    if (timeValue is DateTime) return timeValue;
    final timeStr = timeValue?.toString();
    if (timeStr == null || timeStr.isEmpty) return DateTime.now();
    if (dateStr != null && dateStr.isNotEmpty) {
      final combined = DateTime.tryParse('${dateStr}T$timeStr');
      if (combined != null) return combined;
    }
    // Fallback: try parsing as-is (full ISO string or epoch)
    return DateTime.tryParse(timeStr) ?? DateTime.now();
  }

  static SyncState _parseSyncState(String? value) {
    switch (value) {
      case 'pending':
        return SyncState.pending;
      case 'synced':
        return SyncState.synced;
      case 'failed':
        return SyncState.failed;
      default:
        return SyncState.synced;
    }
  }

  bool get isFullyCollected => amountCollected >= amountExpected;
  bool get isPendingSync => syncStatus == SyncState.pending;
  bool get isSyncFailed => syncStatus == SyncState.failed;
  bool get isCashPayment => paymentMode == PaymentMode.cash;
  bool get isDigitalPayment => !isCashPayment;

  CollectionModel copyWith({
    String? id,
    String? loanId,
    String? loanScheduleId,
    String? memberId,
    String? staffId,
    String? memberName,
    String? memberPhone,
    String? loanNumber,
    double? amountExpected,
    double? amountCollected,
    bool? isPartial,
    bool? isAdvance,
    PaymentMode? paymentMode,
    String? referenceNumber,
    double? gpsLat,
    double? gpsLng,
    double? gpsAccuracy,
    String? gpsAddress,
    DateTime? collectionDate,
    DateTime? collectionTime,
    SyncState? syncStatus,
    String? localId,
    int? syncAttempts,
    DateTime? lastSyncAt,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollectionModel(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      loanScheduleId: loanScheduleId ?? this.loanScheduleId,
      memberId: memberId ?? this.memberId,
      staffId: staffId ?? this.staffId,
      memberName: memberName ?? this.memberName,
      memberPhone: memberPhone ?? this.memberPhone,
      loanNumber: loanNumber ?? this.loanNumber,
      amountExpected: amountExpected ?? this.amountExpected,
      amountCollected: amountCollected ?? this.amountCollected,
      isPartial: isPartial ?? this.isPartial,
      isAdvance: isAdvance ?? this.isAdvance,
      paymentMode: paymentMode ?? this.paymentMode,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      gpsAddress: gpsAddress ?? this.gpsAddress,
      collectionDate: collectionDate ?? this.collectionDate,
      collectionTime: collectionTime ?? this.collectionTime,
      syncStatus: syncStatus ?? this.syncStatus,
      localId: localId ?? this.localId,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        loanId,
        loanScheduleId,
        memberId,
        staffId,
        memberName,
        memberPhone,
        loanNumber,
        amountExpected,
        amountCollected,
        isPartial,
        isAdvance,
        paymentMode,
        referenceNumber,
        gpsLat,
        gpsLng,
        gpsAccuracy,
        gpsAddress,
        collectionDate,
        collectionTime,
        syncStatus,
        localId,
        syncAttempts,
        lastSyncAt,
        remarks,
        createdAt,
        updatedAt,
      ];
}
