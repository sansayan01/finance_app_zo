import 'package:equatable/equatable.dart';

/// Organization branding model
class OrgBrandingModel extends Equatable {
  final String id;
  final String orgId;
  
  // Logos
  final String? logoUrl;
  final String? logoDarkUrl;
  final String? faviconUrl;
  
  // Colors
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String backgroundColor;
  final String textColor;
  
  // Typography
  final String fontFamily;
  final String? headingFont;
  
  // Custom Domain
  final String? customDomain;
  final bool domainVerified;
  
  // Email
  final String? emailHeaderText;
  final String? emailFooterText;
  final String? emailSignature;
  
  // Login Page
  final String? loginBackgroundUrl;
  final String? loginTitle;
  final String? loginSubtitle;
  final String loginButtonText;
  
  // Features
  final Map<String, dynamic> features;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrgBrandingModel({
    required this.id,
    required this.orgId,
    this.logoUrl,
    this.logoDarkUrl,
    this.faviconUrl,
    this.primaryColor = '#3B82F6',
    this.secondaryColor = '#1E40AF',
    this.accentColor = '#10B981',
    this.backgroundColor = '#FFFFFF',
    this.textColor = '#1F2937',
    this.fontFamily = 'Inter',
    this.headingFont,
    this.customDomain,
    this.domainVerified = false,
    this.emailHeaderText,
    this.emailFooterText,
    this.emailSignature,
    this.loginBackgroundUrl,
    this.loginTitle,
    this.loginSubtitle,
    this.loginButtonText = 'Sign In',
    this.features = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrgBrandingModel.fromJson(Map<String, dynamic> json) {
    return OrgBrandingModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      logoUrl: json['logo_url'] as String?,
      logoDarkUrl: json['logo_dark_url'] as String?,
      faviconUrl: json['favicon_url'] as String?,
      primaryColor: json['primary_color'] as String? ?? '#3B82F6',
      secondaryColor: json['secondary_color'] as String? ?? '#1E40AF',
      accentColor: json['accent_color'] as String? ?? '#10B981',
      backgroundColor: json['background_color'] as String? ?? '#FFFFFF',
      textColor: json['text_color'] as String? ?? '#1F2937',
      fontFamily: json['font_family'] as String? ?? 'Inter',
      headingFont: json['heading_font'] as String?,
      customDomain: json['custom_domain'] as String?,
      domainVerified: json['domain_verified'] as bool? ?? false,
      emailHeaderText: json['email_header_text'] as String?,
      emailFooterText: json['email_footer_text'] as String?,
      emailSignature: json['email_signature'] as String?,
      loginBackgroundUrl: json['login_background_url'] as String?,
      loginTitle: json['login_title'] as String?,
      loginSubtitle: json['login_subtitle'] as String?,
      loginButtonText: json['login_button_text'] as String? ?? 'Sign In',
      features: json['features'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'org_id': orgId,
      'logo_url': logoUrl,
      'logo_dark_url': logoDarkUrl,
      'favicon_url': faviconUrl,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'accent_color': accentColor,
      'background_color': backgroundColor,
      'text_color': textColor,
      'font_family': fontFamily,
      'heading_font': headingFont,
      'custom_domain': customDomain,
      'domain_verified': domainVerified,
      'email_header_text': emailHeaderText,
      'email_footer_text': emailFooterText,
      'email_signature': emailSignature,
      'login_background_url': loginBackgroundUrl,
      'login_title': loginTitle,
      'login_subtitle': loginSubtitle,
      'login_button_text': loginButtonText,
      'features': features,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Check if a feature is enabled
  bool hasFeature(String featureName) {
    return features[featureName] == true;
  }

  /// Get color scheme as Theme-friendly format
  Map<String, int> getColorScheme() {
    return {
      'primary': _parseColor(primaryColor),
      'secondary': _parseColor(secondaryColor),
      'accent': _parseColor(accentColor),
      'background': _parseColor(backgroundColor),
      'text': _parseColor(textColor),
    };
  }

  int _parseColor(String hex) {
    return int.parse(hex.replaceFirst('#', 'FF'), radix: 16);
  }

  OrgBrandingModel copyWith({
    String? id,
    String? orgId,
    String? logoUrl,
    String? logoDarkUrl,
    String? faviconUrl,
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? backgroundColor,
    String? textColor,
    String? fontFamily,
    String? headingFont,
    String? customDomain,
    bool? domainVerified,
    String? emailHeaderText,
    String? emailFooterText,
    String? emailSignature,
    String? loginBackgroundUrl,
    String? loginTitle,
    String? loginSubtitle,
    String? loginButtonText,
    Map<String, dynamic>? features,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrgBrandingModel(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      logoUrl: logoUrl ?? this.logoUrl,
      logoDarkUrl: logoDarkUrl ?? this.logoDarkUrl,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      fontFamily: fontFamily ?? this.fontFamily,
      headingFont: headingFont ?? this.headingFont,
      customDomain: customDomain ?? this.customDomain,
      domainVerified: domainVerified ?? this.domainVerified,
      emailHeaderText: emailHeaderText ?? this.emailHeaderText,
      emailFooterText: emailFooterText ?? this.emailFooterText,
      emailSignature: emailSignature ?? this.emailSignature,
      loginBackgroundUrl: loginBackgroundUrl ?? this.loginBackgroundUrl,
      loginTitle: loginTitle ?? this.loginTitle,
      loginSubtitle: loginSubtitle ?? this.loginSubtitle,
      loginButtonText: loginButtonText ?? this.loginButtonText,
      features: features ?? this.features,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, orgId, logoUrl, logoDarkUrl, faviconUrl,
    primaryColor, secondaryColor, accentColor, backgroundColor, textColor,
    fontFamily, headingFont, customDomain, domainVerified,
    emailHeaderText, emailFooterText, emailSignature,
    loginBackgroundUrl, loginTitle, loginSubtitle, loginButtonText,
    features, createdAt, updatedAt,
  ];
}
