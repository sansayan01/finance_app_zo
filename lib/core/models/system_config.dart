import 'package:equatable/equatable.dart';

class SystemConfig extends Equatable {
  final String currentVersionAndroid;
  final String minVersionAndroid;
  final String currentVersionIos;
  final String minVersionIos;
  final String? updateUrlAndroid;
  final String? updateUrlIos;
  final String updateMessage;
  final bool isUnderMaintenance;
  final String maintenanceMessage;

  const SystemConfig({
    required this.currentVersionAndroid,
    required this.minVersionAndroid,
    required this.currentVersionIos,
    required this.minVersionIos,
    this.updateUrlAndroid,
    this.updateUrlIos,
    required this.updateMessage,
    required this.isUnderMaintenance,
    required this.maintenanceMessage,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    return SystemConfig(
      currentVersionAndroid: json['current_version_android'] ?? '1.0.0',
      minVersionAndroid: json['min_version_android'] ?? '1.0.0',
      currentVersionIos: json['current_version_ios'] ?? '1.0.0',
      minVersionIos: json['min_version_ios'] ?? '1.0.0',
      updateUrlAndroid: json['update_url_android'],
      updateUrlIos: json['update_url_ios'],
      updateMessage: json['update_message'] ?? 'A new version is available. Please update to continue.',
      isUnderMaintenance: json['is_under_maintenance'] ?? false,
      maintenanceMessage: json['maintenance_message'] ?? 'MicroFlow Pro is currently under maintenance.',
    );
  }

  @override
  List<Object?> get props => [
        currentVersionAndroid,
        minVersionAndroid,
        currentVersionIos,
        minVersionIos,
        updateUrlAndroid,
        updateUrlIos,
        updateMessage,
        isUnderMaintenance,
        maintenanceMessage,
      ];
}
