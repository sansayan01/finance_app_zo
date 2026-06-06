import 'dart:typed_data';

/// Shared organisation info model for all statement PDFs.
///
/// Both `LoanStatementOrgInfo` and `SavingsStatementOrgInfo` had identical
/// fields.  This single class replaces both.
class StatementOrgInfo {
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? phone;
  final String? email;
  final String? gstNumber;
  final Uint8List? logoBytes;

  const StatementOrgInfo({
    required this.name,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.phone,
    this.email,
    this.gstNumber,
    this.logoBytes,
  });

  /// Default fallback when no org info is available.
  factory StatementOrgInfo.fallback() =>
      const StatementOrgInfo(name: 'MicroFlow Pro');

  String get fullAddress {
    final parts = <String>[
      if (address != null && address!.trim().isNotEmpty) address!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (pincode != null && pincode!.trim().isNotEmpty) pincode!.trim(),
    ];
    return parts.join(', ');
  }
}
