class BrandModel {
  final String name;
  final String iconPreset;

  BrandModel({
    required this.name,
    this.iconPreset = 'default',
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      name: json['brand_name'] as String? ?? 'MicroFlow Pro',
      iconPreset: json['icon_preset'] as String? ?? 'default',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand_name': name,
      'icon_preset': iconPreset,
    };
  }

  BrandModel copyWith({
    String? name,
    String? iconPreset,
  }) {
    return BrandModel(
      name: name ?? this.name,
      iconPreset: iconPreset ?? this.iconPreset,
    );
  }
}
