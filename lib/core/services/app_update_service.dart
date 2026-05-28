import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum DownloadState { idle, downloading, completed, failed }

class DownloadProgress {
  final DownloadState state;
  final double progress;
  final String? error;
  final String? filePath;

  const DownloadProgress({
    this.state = DownloadState.idle,
    this.progress = 0.0,
    this.error,
    this.filePath,
  });
}

class AppUpdateService {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  final _stateController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progressStream => _stateController.stream;

  DownloadProgress _current = const DownloadProgress();
  DownloadProgress get current => _current;

  void _update(DownloadProgress p) {
    _current = p;
    _stateController.add(p);
  }

  Future<void> downloadAndInstall(String url) async {
    if (_current.state == DownloadState.downloading) return;

    try {
      // Request storage permission on older Android versions
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          _update(const DownloadProgress(
            state: DownloadState.failed,
            error: 'Install permission denied. Please allow app installs.',
          ));
          return;
        }
      }

      _update(const DownloadProgress(state: DownloadState.downloading));
      _cancelToken = CancelToken();

      // Use external cache directory — accessible by FileProvider
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/microflow_update.apk';

      // Delete old file if exists
      final oldFile = File(filePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      await _dio.download(
        url,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final progress = received / total;
          _update(DownloadProgress(
            state: DownloadState.downloading,
            progress: progress,
            filePath: filePath,
          ));
        },
      );

      _update(DownloadProgress(
        state: DownloadState.completed,
        progress: 1.0,
        filePath: filePath,
      ));

      // Auto-trigger install
      await _installApk(filePath);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _update(const DownloadProgress(
          state: DownloadState.failed,
          error: 'Download cancelled.',
        ));
      } else {
        _update(DownloadProgress(
          state: DownloadState.failed,
          error: 'Download failed: ${e.message}',
        ));
      }
    } catch (e) {
      debugPrint('❌ Download error: $e');
      _update(DownloadProgress(
        state: DownloadState.failed,
        error: 'Download failed: $e',
      ));
    }
  }

  Future<void> _installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      debugPrint('📦 Install result: ${result.type} - ${result.message}');
    } catch (e) {
      debugPrint('❌ Install error: $e');
    }
  }

  /// Re-trigger install for a previously downloaded file
  Future<void> installFromPath(String filePath) async {
    await _installApk(filePath);
  }

  void cancelDownload() {
    _cancelToken?.cancel();
    _cancelToken = null;
    _update(const DownloadProgress(state: DownloadState.idle));
  }

  void reset() {
    _cancelToken?.cancel();
    _cancelToken = null;
    _current = const DownloadProgress();
    _stateController.add(_current);
  }

  void dispose() {
    _cancelToken?.cancel();
    _stateController.close();
    _dio.close();
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final service = AppUpdateService();
  ref.onDispose(() => service.dispose());
  return service;
});
