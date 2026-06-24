import 'dart:typed_data';

/// Shared organisation info model for all statement PDFs.
///
/// Both `LoanStatementOrgInfo` and `SavingsStatementOrgInfo` had identical
/// fields.  This single class replaces both.
///
/// The optional regulatory fields ([registrationNumber], [grievanceOfficer],
/// etc.) are used by the premium statement template to display compliance
/// information.  They are safe to leave null — the PDF simply omits those
/// sections.
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

  // ── Premium / Regulatory Fields ──
  /// RBI / NBFC / MFI registration or license number.
  final String? registrationNumber;

  /// Name of the designated grievance officer (regulatory requirement).
  final String? grievanceOfficer;

  /// Phone number of the grievance officer.
  final String? grievancePhone;

  /// Organisation website URL.
  final String? website;

  /// Brand tagline displayed on the letterhead.
  final String? tagline;

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
    this.registrationNumber,
    this.grievanceOfficer,
    this.grievancePhone,
    this.website,
    this.tagline,
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
