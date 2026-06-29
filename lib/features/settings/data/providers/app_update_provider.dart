import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/core/models/app_update.dart';
import 'package:microflow_pro/core/models/app_update_status.dart';
import 'package:microflow_pro/features/settings/data/repositories/app_update_repository.dart';

/// Streams the active app_updates row from Supabase.
/// Re-emits every 30 seconds so admins see new rows quickly without
/// the need for a full Realtime subscription.
final androidUpdateStatusProvider =
    StreamProvider<AppUpdateCheckResult>((ref) async* {
  final repo = ref.watch(appUpdateRepositoryProvider);

  yield _derive(await repo.fetchLatestActiveForAndroid());

  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    yield _derive(await repo.fetchLatestActiveForAndroid());
  }
});

AppUpdateCheckResult _derive(AppUpdate? row) {
  if (row == null) {
    return const AppUpdateCheckResult(status: AppUpdateStatus.noUpdate);
  }
  if (row.isCritical) {
    return AppUpdateCheckResult(
      status: AppUpdateStatus.mustUpdate,
      update: row,
      message: row.releaseNotes,
    );
  }
  return AppUpdateCheckResult(
    status: AppUpdateStatus.available,
    update: row,
    message: row.releaseNotes,
  );
}
