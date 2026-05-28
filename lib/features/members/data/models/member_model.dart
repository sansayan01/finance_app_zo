import 'package:microflow_pro/core/constants/enums.dart';

class MemberModel {
  final String id;
  final String fullName;
  final String phone;
  final String memberId;
  final KYCStatus kycStatus;
  final int activeLoans;
  final double totalSavings;
  final DateTime createdAt;
  final String? orgId;
  final String? shopName;
  final String? businessType;
  final double? latitude;
  final double? longitude;
  final String? shopPhotoUrl;

  MemberModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.memberId,
    required this.kycStatus,
    this.activeLoans = 0,
    this.totalSavings = 0,
    required this.createdAt,
    this.orgId,
    this.shopName,
    this.businessType,
    this.latitude,
    this.longitude,
    this.shopPhotoUrl,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    KYCStatus status = KYCStatus.pending;
    final kycString = json['kyc_status'] as String?;
    if (kycString == 'verified') status = KYCStatus.verified;
    if (kycString == 'rejected') status = KYCStatus.rejected;

    return MemberModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Unknown',
      phone: json['phone'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      kycStatus: status,
      activeLoans: json['active_loans'] as int? ?? 0,
      totalSavings: (json['total_savings'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      orgId: json['org_id'] as String?,
      shopName: json['shop_name'] as String?,
      businessType: json['business_type'] as String?,
      latitude: (json['gps_lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble(),
      longitude: (json['gps_lng'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble(),
      shopPhotoUrl: json['shop_photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'member_id': memberId,
      'kyc_status': kycStatus == KYCStatus.pending ? 'pending' : kycStatus.name,
      'active_loans': activeLoans,
      'total_savings': totalSavings,
      'org_id': orgId,
      'created_at': createdAt.toIso8601String(),
      'shop_name': shopName,
      'business_type': businessType,
      'gps_lat': latitude,
      'gps_lng': longitude,
      'shop_photo_url': shopPhotoUrl,
    };
  }
}

class MemberSummary {
  final int totalMembers;
  final int activeMembers;
  final int pendingKYC;

  MemberSummary({
    required this.totalMembers,
    required this.activeMembers,
    required this.pendingKYC,
  });
}
