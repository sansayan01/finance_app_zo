import 'app_update.dart';

/// Four-way user-facing status derived from the installed version vs
/// the current config. Used by UpdateWrapper to render the correct screen.
enum AppUpdateStatus {
  noUpdate,        // app is current
  available,       // newer build published, below min → soft
  mustUpdate,      // installed version < minSupportedVersion → force
  maintenance,     // platform-wide maintenance mode
}

class AppUpdateCheckResult {
  final AppUpdateStatus status;
  final AppUpdate? update;
  final String? message;

  const AppUpdateCheckResult({
    required this.status,
    this.update,
    this.message,
  });

  bool get isMustUpdate => status == AppUpdateStatus.mustUpdate;
  bool get isMaintenance => status == AppUpdateStatus.maintenance;
  bool get hasUpdate => status != AppUpdateStatus.noUpdate;
}
