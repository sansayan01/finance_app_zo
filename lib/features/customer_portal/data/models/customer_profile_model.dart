class CustomerProfileModel {
  final String memberId;
  final String fullName;
  final String? fatherName;
  final String phone;
  final String? email;
  final String kycStatus;
  final String? area;
  final String? village;
  final String? address;
  final String? aadharNumber;
  final String? panNumber;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? occupation;
  final double? monthlyIncome;
  final String? profileId;
  final DateTime? joinedDate;
  final int totalLoans;
  final double totalSavings;

  const CustomerProfileModel({
    required this.memberId,
    required this.fullName,
    this.fatherName,
    required this.phone,
    this.email,
    required this.kycStatus,
    this.area,
    this.village,
    this.address,
    this.aadharNumber,
    this.panNumber,
    this.dateOfBirth,
    this.gender,
    this.occupation,
    this.monthlyIncome,
    this.profileId,
    this.joinedDate,
    this.totalLoans = 0,
    this.totalSavings = 0,
  });

  factory CustomerProfileModel.fromJson(Map<String, dynamic> json) {
    return CustomerProfileModel(
      memberId: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      fatherName: json['father_name']?.toString(),
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      kycStatus: json['kyc_status']?.toString() ?? 'pending',
      area: json['area']?.toString(),
      village: json['village']?.toString(),
      address: json['address']?.toString(),
      aadharNumber: json['aadhar_number']?.toString(),
      panNumber: json['pan_number']?.toString(),
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'].toString())
          : null,
      gender: json['gender']?.toString(),
      occupation: json['occupation']?.toString(),
      monthlyIncome: (json['monthly_income'] as num?)?.toDouble(),
      profileId: json['profile_id']?.toString(),
      joinedDate: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      totalLoans: json['total_loans'] as int? ?? 0,
      totalSavings: (json['total_savings'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'father_name': fatherName,
      'phone': phone,
      'email': email,
      'kyc_status': kycStatus,
      'area': area,
      'village': village,
      'address': address,
      'aadhar_number': aadharNumber,
      'pan_number': panNumber,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'gender': gender,
      'occupation': occupation,
      'monthly_income': monthlyIncome,
    };
  }

  String get maskedAadhar {
    if (aadharNumber == null || aadharNumber!.length < 4) return '****';
    return '****${aadharNumber!.substring(aadharNumber!.length - 4)}';
  }

  String get maskedPan {
    if (panNumber == null || panNumber!.length < 4) return '****';
    return '****${panNumber!.substring(panNumber!.length - 4)}';
  }

  String get initials {
    final parts = fullName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String get formattedDob {
    if (dateOfBirth == null) return '--';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dateOfBirth!.day} ${months[dateOfBirth!.month - 1]} ${dateOfBirth!.year}';
  }

  String get formattedJoinedDate {
    if (joinedDate == null) return '--';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${joinedDate!.day} ${months[joinedDate!.month - 1]} ${joinedDate!.year}';
  }

  String get formattedMonthlyIncome {
    if (monthlyIncome == null) return '--';
    if (monthlyIncome! >= 10000000) {
      return '\u20b9${(monthlyIncome! / 10000000).toStringAsFixed(1)}Cr';
    } else if (monthlyIncome! >= 100000) {
      return '\u20b9${(monthlyIncome! / 100000).toStringAsFixed(1)}L';
    } else if (monthlyIncome! >= 1000) {
      return '\u20b9${(monthlyIncome! / 1000).toStringAsFixed(1)}K';
    }
    return '\u20b9${monthlyIncome!.toStringAsFixed(0)}';
  }

  CustomerProfileModel copyWith({
    String? fullName,
    String? phone,
    String? email,
    String? area,
    String? village,
    String? address,
    String? gender,
    String? occupation,
    double? monthlyIncome,
    DateTime? dateOfBirth,
  }) {
    return CustomerProfileModel(
      memberId: memberId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      kycStatus: kycStatus,
      area: area ?? this.area,
      village: village ?? this.village,
      address: address ?? this.address,
      aadharNumber: aadharNumber,
      panNumber: panNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      occupation: occupation ?? this.occupation,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      profileId: profileId,
      joinedDate: joinedDate,
      totalLoans: totalLoans,
      totalSavings: totalSavings,
    );
  }
}
