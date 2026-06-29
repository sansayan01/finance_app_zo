import 'package:equatable/equatable.dart';

/// Single release row drawn from the `app_updates` table.
class AppUpdate extends Equatable {
  final String id;
  final String version;            // e.g. "1.1.0"
  final String platform;           // 'android' | 'ios' | 'all'
  final String? releaseNotes;
  final bool isCritical;           // true => must-update
  final String? minSupportedVersion; // e.g. "1.0.0" — any version below this is forced
  final String downloadUrl;
  final String? apkPath;
  final String? firebaseAppId;
  final double? fileSizeMb;
  final DateTime publishedAt;

  const AppUpdate({
    required this.id,
    required this.version,
    required this.platform,
    this.releaseNotes,
    this.isCritical = false,
    this.minSupportedVersion,
    this.downloadUrl = '',
    this.apkPath,
    this.firebaseAppId,
    this.fileSizeMb,
    required this.publishedAt,
  });

  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    return AppUpdate(
      id: json['id']?.toString() ?? '',
      version: (json['version'] ?? '1.0.0').toString(),
      platform: (json['platform'] ?? 'android').toString(),
      releaseNotes: json['release_notes'] as String?,
      isCritical: json['is_critical'] == true || json['is_critical'] == 1,
      minSupportedVersion: json['min_supported_version'] as String?,
      downloadUrl: (json['download_url'] ?? json['update_url'] ?? '').toString(),
      apkPath: json['apk_path'] as String?,
      firebaseAppId: json['firebase_app_id'] as String?,
      fileSizeMb: json['file_size_mb'] != null
          ? double.tryParse(json['file_size_mb'].toString())
          : null,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'].toString()).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'platform': platform,
    'release_notes': releaseNotes,
    'is_critical': isCritical,
    'min_supported_version': minSupportedVersion,
    'download_url': downloadUrl,
    'apk_path': apkPath,
    'firebase_app_id': firebaseAppId,
    'file_size_mb': fileSizeMb,
    'published_at': publishedAt.toUtc().toIso8601String(),
  };

  bool get isForAndroid =>
      platform.toLowerCase() == 'android' || platform.toLowerCase() == 'all';

  bool get isAvailableLocally {
    // A user considers this version "seen" once the running app version
    // matches — new pushes re-trigger the prompt.
    return publishedAt.isBefore(DateTime.now().add(const Duration(days: -1)));
  }

  @override
  List<Object?> get props => [
    id,
    version,
    platform,
    releaseNotes,
    isCritical,
    minSupportedVersion,
    downloadUrl,
    apkPath,
    firebaseAppId,
    fileSizeMb,
    publishedAt,
  ];
}
