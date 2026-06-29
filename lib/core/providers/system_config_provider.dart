import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_config.dart';
import '../models/github_release.dart';
import '../services/github_release_service.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

/// Streams system_config changes in real-time via Supabase Realtime.
/// Falls back to a one-time fetch if realtime isn't available.
final systemConfigProvider = StreamProvider<SystemConfig>((ref) {
  final client = ref.watch(supabaseClientProvider);

  final controller = StreamController<SystemConfig>();

  // 1. Fetch initial value immediately
  Future<void> fetchInitial() async {
    try {
      final response =
          await client.from('system_config').select().limit(1).maybeSingle();
      if (response != null) {
        controller.add(SystemConfig.fromJson(response));
      } else {
        controller.add(_defaultConfig);
      }
    } catch (e) {
      debugPrint('⚠️ system_config fetch error: $e');
      controller.add(_defaultConfig);
    }
  }

  fetchInitial();

  // 2. Subscribe to realtime changes on system_config
  final channel = client
      .channel('system_config_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'system_config',
        callback: (payload) {
          debugPrint('🔔 system_config updated via Realtime');
          final newData = payload.newRecord;
          if (newData.isNotEmpty) {
            controller.add(SystemConfig.fromJson(newData));
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

const _defaultConfig = SystemConfig(
  currentVersionAndroid: '1.0.0',
  minVersionAndroid: '1.0.0',
  currentVersionIos: '1.0.0',
  minVersionIos: '1.0.0',
  updateMessage: '',
  isUnderMaintenance: false,
  maintenanceMessage: '',
);

// ─── Update Check ───────────────────────────────────────────────────────────

enum UpdateStatus {
  noUpdate,
  softUpdate,
  forceUpdate,
  maintenance,
}

class UpdateCheckResult {
  final UpdateStatus status;
  final String? updateUrl;
  final String? message;
  final String? releaseNotes;

  const UpdateCheckResult({
    required this.status,
    this.updateUrl,
    this.message,
    this.releaseNotes,
  });
}

/// Fetches the latest GitHub release info.
/// Cached for the session lifetime; invalidated on app resume.
final githubReleaseProvider = FutureProvider<GitHubRelease?>((ref) async {
  final service = ref.watch(githubReleaseServiceProvider);
  return service.fetchLatestRelease();
});

/// Derives the update status from BOTH:
/// - system_config stream (Supabase Realtime) — for min_version_android,
///   is_under_maintenance, update_message
/// - GitHub Releases API — for latest version, download URL, release notes
///
/// If GitHub is unreachable, falls back to system_config data only.
final updateCheckProvider = Provider<AsyncValue<UpdateCheckResult>>((ref) {
  final configAsync = ref.watch(systemConfigProvider);

  return configAsync.when(
    data: (config) {
      // Maintenance check is independent of GitHub
      if (config.isUnderMaintenance) {
        return AsyncValue.data(
          UpdateCheckResult(
            status: UpdateStatus.maintenance,
            message: config.maintenanceMessage,
          ),
        );
      }

      if (!_isMobile || _cachedAppVersion == null) {
        return const AsyncValue.data(
          UpdateCheckResult(status: UpdateStatus.noUpdate),
        );
      }

      // Try to use GitHub release data (the new source of truth)
      final githubRelease = ref.watch(githubReleaseProvider).valueOrNull;

      if (githubRelease != null && githubRelease.apkDownloadUrl != null) {
        return AsyncValue.data(
          _checkUpdateWithGitHub(config, githubRelease),
        );
      }

      // Fallback: GitHub unavailable — use system_config data
      return AsyncValue.data(_checkUpdate(config));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Primary update check using GitHub Releases as source of truth.
UpdateCheckResult _checkUpdateWithGitHub(
  SystemConfig config,
  GitHubRelease release,
) {
  final currentAppVersion = _cachedAppVersion!;
  final targetVersion = release.version;
  final downloadUrl = release.apkDownloadUrl;

  String targetMinVersion;
  if (Platform.isAndroid) {
    targetMinVersion = config.minVersionAndroid;
  } else if (Platform.isIOS) {
    targetMinVersion = config.minVersionIos;
  } else {
    return const UpdateCheckResult(status: UpdateStatus.noUpdate);
  }

  // Force update if below minimum version
  if (_isVersionLower(currentAppVersion, targetMinVersion)) {
    return UpdateCheckResult(
      status: UpdateStatus.forceUpdate,
      updateUrl: downloadUrl,
      message: config.updateMessage,
      releaseNotes: release.body,
    );
  }

  // Soft update if newer version available
  if (_isVersionLower(currentAppVersion, targetVersion)) {
    return UpdateCheckResult(
      status: UpdateStatus.softUpdate,
      updateUrl: downloadUrl,
      message: config.updateMessage,
      releaseNotes: release.body,
    );
  }

  return const UpdateCheckResult(status: UpdateStatus.noUpdate);
}

/// Legacy check using only system_config (used when GitHub is unreachable).
UpdateCheckResult _checkUpdate(SystemConfig config) {
  if (config.isUnderMaintenance) {
    return UpdateCheckResult(
      status: UpdateStatus.maintenance,
      message: config.maintenanceMessage,
    );
  }

  if (!_isMobile) {
    return const UpdateCheckResult(status: UpdateStatus.noUpdate);
  }

  final currentAppVersion = _cachedAppVersion;
  if (currentAppVersion == null) {
    return const UpdateCheckResult(status: UpdateStatus.noUpdate);
  }

  String targetMinVersion;
  String targetCurrentVersion;
  String? updateUrl;

  if (Platform.isAndroid) {
    targetMinVersion = config.minVersionAndroid;
    targetCurrentVersion = config.currentVersionAndroid;
    updateUrl = config.updateUrlAndroid;
  } else if (Platform.isIOS) {
    targetMinVersion = config.minVersionIos;
    targetCurrentVersion = config.currentVersionIos;
    updateUrl = config.updateUrlIos;
  } else {
    return const UpdateCheckResult(status: UpdateStatus.noUpdate);
  }

  if (_isVersionLower(currentAppVersion, targetMinVersion)) {
    return UpdateCheckResult(
      status: UpdateStatus.forceUpdate,
      updateUrl: updateUrl,
      message: config.updateMessage,
    );
  }

  if (_isVersionLower(currentAppVersion, targetCurrentVersion)) {
    return UpdateCheckResult(
      status: UpdateStatus.softUpdate,
      updateUrl: updateUrl,
      message: config.updateMessage,
    );
  }

  return const UpdateCheckResult(status: UpdateStatus.noUpdate);
}

bool get _isMobile {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

// Cache the app version so we don't need async in the synchronous provider
String? _cachedAppVersion;

/// Call this once at app startup to cache the version string.
Future<void> initAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  _cachedAppVersion = info.version;
  debugPrint('📱 App version: $_cachedAppVersion');
}

bool _isVersionLower(String current, String target) {
  try {
    final currentParts = current.split('.').map(int.parse).toList();
    final targetParts = target.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final t = i < targetParts.length ? targetParts[i] : 0;
      if (c < t) return true;
      if (c > t) return false;
    }
    return false;
  } catch (e) {
    return false;
  }
}
