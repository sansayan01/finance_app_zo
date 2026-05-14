import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import '../models/system_config.dart';
import '../../../providers/supabase_provider.dart';

final systemConfigProvider = FutureProvider<SystemConfig>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  
  final response = await client
      .from('system_config')
      .select()
      .limit(1)
      .maybeSingle();
      
  if (response == null) {
    return const SystemConfig(
      currentVersionAndroid: '1.0.0',
      minVersionAndroid: '1.0.0',
      currentVersionIos: '1.0.0',
      minVersionIos: '1.0.0',
      updateMessage: '',
      isUnderMaintenance: false,
      maintenanceMessage: '',
    );
  }
  
  return SystemConfig.fromJson(response);
});

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

  UpdateCheckResult({
    required this.status,
    this.updateUrl,
    this.message,
  });
}

final updateCheckProvider = FutureProvider<UpdateCheckResult>((ref) async {
  final config = await ref.watch(systemConfigProvider.future);
  final packageInfo = await PackageInfo.fromPlatform();
  final currentAppVersion = packageInfo.version;
  
  if (config.isUnderMaintenance) {
    return UpdateCheckResult(
      status: UpdateStatus.maintenance,
      message: config.maintenanceMessage,
    );
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
    return UpdateCheckResult(status: UpdateStatus.noUpdate);
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

  return UpdateCheckResult(status: UpdateStatus.noUpdate);
});

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
