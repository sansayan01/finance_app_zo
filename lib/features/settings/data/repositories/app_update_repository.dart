import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/core/models/app_update.dart';
import 'package:microflow_pro/features/settings/data/datasources/app_update_api.dart';

class AppUpdateRepository {
  final AppUpdateApi _api;
  AppUpdateRepository(this._api);

  /// Most-recent active update for Android — what drives the UpdateWrapper.
  Future<AppUpdate?> fetchLatestActiveForAndroid() =>
      _api.fetchLatestActiveForAndroid();

  Future<List<AppUpdate>> fetchActiveForAndroid() =>
      _api.fetchActiveForAndroid();

  /// Publish a new update row (used by the admin page alongside the
  /// existing system_config PATCH).
  Future<AppUpdate> create({
    required String version,
    required String downloadUrl,
    String platform = 'android',
    String? releaseNotes,
    bool isCritical = false,
    String? minSupportedVersion,
    double? fileSizeMb,
  }) async {
    return _api.createAppUpdate(
      version: version,
      downloadUrl: downloadUrl,
      platform: platform,
      releaseNotes: releaseNotes,
      isCritical: isCritical,
      minSupportedVersion: minSupportedVersion,
      fileSizeMb: fileSizeMb,
    );
  }
}

final appUpdateRepositoryProvider =
Provider<AppUpdateRepository>((ref) {
  final api = ref.watch(appUpdateApiProvider);
  return AppUpdateRepository(api);
});
