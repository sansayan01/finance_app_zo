import 'package:equatable/equatable.dart';

/// Represents a single asset attached to a GitHub Release.
class GitHubReleaseAsset extends Equatable {
  final String name;
  final String browserDownloadUrl;
  final int size;
  final String contentType;

  const GitHubReleaseAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
    required this.contentType,
  });

  factory GitHubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return GitHubReleaseAsset(
      name: json['name'] as String? ?? '',
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      contentType: json['content_type'] as String? ?? '',
    );
  }

  /// Whether this asset is the universal APK (not a split APK).
  bool get isUniversalApk =>
      name == 'app-release.apk' ||
      (name.endsWith('.apk') && !name.contains('arm') && !name.contains('x86'));

  @override
  List<Object?> get props => [name, browserDownloadUrl, size];
}

/// Represents a GitHub Release from the GitHub API.
///
/// Used to check for new app versions by comparing [version] against
/// the installed app version. The APK download URL is extracted from [assets].
class GitHubRelease extends Equatable {
  final String tagName;
  final String? body;
  final List<GitHubReleaseAsset> assets;
  final DateTime? publishedAt;

  const GitHubRelease({
    required this.tagName,
    this.body,
    this.assets = const [],
    this.publishedAt,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    return GitHubRelease(
      tagName: (json['tag_name'] ?? '').toString(),
      body: json['body'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)?.toLocal()
          : null,
      assets: (json['assets'] as List?)
              ?.map((a) =>
                  GitHubReleaseAsset.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// The version string without the leading 'v' and build suffix.
  /// E.g., "v1.0.9+2011" → "1.0.9"
  String get version => tagName
      .replaceFirst(RegExp(r'^v'), '')
      .split('+')
      .first;

  /// The universal APK download URL (app-release.apk).
  /// Returns null if no suitable asset is found.
  String? get apkDownloadUrl {
    // Prefer the exact universal APK name
    for (final asset in assets) {
      if (asset.name == 'app-release.apk') {
        return asset.browserDownloadUrl.isNotEmpty
            ? asset.browserDownloadUrl
            : null;
      }
    }
    // Fallback: find any APK that isn't a split APK
    for (final asset in assets) {
      if (asset.isUniversalApk && asset.browserDownloadUrl.isNotEmpty) {
        return asset.browserDownloadUrl;
      }
    }
    return null;
  }

  /// Total size of the universal APK in bytes.
  int get apkSize {
    for (final asset in assets) {
      if (asset.name == 'app-release.apk') return asset.size;
    }
    return 0;
  }

  @override
  List<Object?> get props => [tagName, body, assets, publishedAt];
}
