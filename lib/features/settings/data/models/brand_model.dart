class BrandModel {
  final String name;
  final String? logoUrl;
  final String? primaryColor;
  final String iconPreset;

  BrandModel({
    required this.name,
    this.logoUrl,
    this.primaryColor,
    this.iconPreset = 'default',
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      name: json['brand_name'] as String? ?? 'MicroFlow Pro',
      logoUrl: json['brand_logo_url'] as String?,
      primaryColor: json['primary_color'] as String?,
      iconPreset: json['icon_preset'] as String? ?? 'default',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand_name': name,
      'brand_logo_url': logoUrl,
      'primary_color': primaryColor,
      'icon_preset': iconPreset,
    };
  }

  BrandModel copyWith({
    String? name,
    String? logoUrl,
    String? primaryColor,
    String? iconPreset,
  }) {
    return BrandModel(
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      iconPreset: iconPreset ?? this.iconPreset,
    );
  }
}
