import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

enum DownloadState { idle, downloading, completed, failed }

class AppUpdateService {
  String? _taskId;
  Timer? _pollTimer;

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

    final dir = await getApplicationDocumentsDirectory();
    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: dir.path,
      fileName: 'microflow_update.apk',
      showNotification: true,
      openFileFromNotification: false,
    );

    if (taskId == null) {
      _update(const DownloadProgress(
        state: DownloadState.failed,
        error: 'Failed to start download.',
      ));
      return;
    }

    _taskId = taskId;
    _update(const DownloadProgress(state: DownloadState.downloading));
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_taskId == null) return;
      final tasks = await FlutterDownloader.loadTasksWithRawQuery(
          query: "SELECT * FROM task WHERE task_id='$_taskId'");
      if (tasks == null || tasks.isEmpty) return;

      final task = tasks.first;
      if (task.status == DownloadTaskStatus.running) {
        _update(DownloadProgress(
          state: DownloadState.downloading,
          progress: task.progress / 100.0,
        ));
      } else if (task.status == DownloadTaskStatus.complete) {
        _pollTimer?.cancel();
        _update(const DownloadProgress(state: DownloadState.completed));
        _installApk();
      } else if (task.status == DownloadTaskStatus.failed) {
        _pollTimer?.cancel();
        _update(const DownloadProgress(
          state: DownloadState.failed,
          error: 'Download failed.',
        ));
      }
    });
  }

  Future<void> _installApk() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/microflow_update.apk';
    OpenFilex.open(path, type: 'application/vnd.android.package-archive');
  }

  void reset() {
    _pollTimer?.cancel();
    _current = const DownloadProgress();
    _stateController.add(_current);
  }

  void dispose() {
    _pollTimer?.cancel();
    _stateController.close();
  }
}

class DownloadProgress {
  final DownloadState state;
  final double progress;
  final String? error;

  const DownloadProgress({
    this.state = DownloadState.idle,
    this.progress = 0.0,
    this.error,
  });
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});
