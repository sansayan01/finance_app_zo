import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/system_config_provider.dart';
import '../services/github_release_service.dart';
import '../services/notification_service.dart';

/// Periodically checks GitHub for new releases and auto-downloads the APK.
/// When the download completes, a notification prompts the user to install.
class AutoUpdateService {
  final GitHubReleaseService _releaseService;
  Timer? _timer;
  bool _checking = false;
  bool _downloadComplete = false;
  String? _lastCheckedVersion;

  AutoUpdateService(this._releaseService);

  /// Start periodic checking (every 30 minutes) + immediate first check.
  void start() {
    // Initial check after a short delay (let app fully load)
    Future.delayed(const Duration(seconds: 30), _checkAndUpdate);

    // Periodic check every 30 minutes
    _timer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _checkAndUpdate(),
    );
    debugPrint('🔄 AutoUpdateService started (30 min interval)');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Core logic: check GitHub, compare version, download if newer.
  Future<void> _checkAndUpdate() async {
    if (_checking || _downloadComplete) return;
    _checking = true;

    try {
      // Get installed version
      final info = await PackageInfo.fromPlatform();
      final installedVersion = info.version;

      // Fetch latest GitHub release
      final release = await _releaseService.fetchLatestRelease();
      if (release == null || release.apkDownloadUrl == null) {
        _checking = false;
        return;
      }

      final latestVersion = release.version;

      // Skip if same version already checked
      if (_lastCheckedVersion == latestVersion) {
        _checking = false;
        return;
      }
      _lastCheckedVersion = latestVersion;

      // Compare versions
      if (!isVersionLower(installedVersion, latestVersion)) {
        debugPrint('🔄 AutoUpdate: app is up to date ($installedVersion)');
        _checking = false;
        return;
      }

      debugPrint(
          '🔄 AutoUpdate: new version available ($installedVersion → $latestVersion)');

      // Check if APK already downloaded
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/microflow_update.apk';
      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        debugPrint('🔄 AutoUpdate: APK already downloaded, notifying');
        await NotificationService.showUpdateReadyNotification(latestVersion);
        _downloadComplete = true;
        _checking = false;
        return;
      }

      // Request notification permission on Android 13+ before downloading
      // so we can notify the user when the download completes.
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (status.isDenied || status.isPermanentlyDenied) {
          await Permission.notification.request();
        }
      }

      // Download in background
      await _downloadApk(release.apkDownloadUrl!, latestVersion);
    } catch (e) {
      debugPrint('❌ AutoUpdate check failed: $e');
    } finally {
      _checking = false;
    }
  }

  /// Download the APK silently in the background.
  Future<void> _downloadApk(String url, String version) async {
    try {
      final dio = Dio();
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/microflow_update.apk';

      // Delete old file if exists
      final oldFile = File(filePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      debugPrint('🔄 AutoUpdate: downloading APK...');
      await dio.download(url, filePath);

      debugPrint('🔄 AutoUpdate: download complete, showing notification');
      _downloadComplete = true;
      await NotificationService.showUpdateReadyNotification(version);
    } catch (e) {
      debugPrint('❌ AutoUpdate download failed: $e');
    }
  }

  /// Reset state so a new version can be downloaded.
  void reset() {
    _downloadComplete = false;
    _lastCheckedVersion = null;
  }

  void dispose() {
    stop();
  }
}

/// Provider for AutoUpdateService — starts automatically when first read.
final autoUpdateServiceProvider = Provider<AutoUpdateService>((ref) {
  final releaseService = ref.read(githubReleaseServiceProvider);
  final service = AutoUpdateService(releaseService);
  service.start();
  ref.onDispose(() => service.dispose());
  return service;
});
