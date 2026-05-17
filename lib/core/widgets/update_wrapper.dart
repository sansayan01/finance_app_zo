import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/system_config_provider.dart';
import '../services/app_update_service.dart';

class UpdateWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const UpdateWrapper({super.key, required this.child});

  @override
  ConsumerState<UpdateWrapper> createState() => _UpdateWrapperState();
}

class _UpdateWrapperState extends ConsumerState<UpdateWrapper> {
  StreamSubscription? _progressSub;
  DownloadProgress _downloadProgress = const DownloadProgress();
  bool _dialogShown = false;

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  void _startListening(AppUpdateService service) {
    _progressSub?.cancel();
    _progressSub = service.progressStream.listen((p) {
      if (!mounted) return;
      setState(() => _downloadProgress = p);
    });
  }

  Future<void> _startDownload(AppUpdateService service, String url) async {
    _startListening(service);
    await service.downloadAndInstall(url);
  }

  @override
  Widget build(BuildContext context) {
    final updateCheck = ref.watch(updateCheckProvider);

    return updateCheck.when(
      data: (result) {
        if (result.status == UpdateStatus.noUpdate) {
          _dialogShown = false;
          return widget.child;
        }

        if (result.status == UpdateStatus.maintenance) {
          return _MaintenanceOverlay(message: result.message);
        }

        final isForce = result.status == UpdateStatus.forceUpdate;

        if (!_dialogShown) {
          _dialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTelegramUpdateDialog(context, result, isForce);
          });
        }

        return isForce
            ? Stack(children: [widget.child, const _BlockingOverlay()])
            : widget.child;
      },
      loading: () => widget.child,
      error: (_, __) => widget.child,
    );
  }

  void _showTelegramUpdateDialog(
      BuildContext context, UpdateCheckResult result, bool isForce) {
    final service = ref.read(appUpdateServiceProvider);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDownloading =
                _downloadProgress.state == DownloadState.downloading;
            final isCompleted =
                _downloadProgress.state == DownloadState.completed;
            final isFailed = _downloadProgress.state == DownloadState.failed;
            final progress = _downloadProgress.progress;
            final pct = (progress * 100).toInt();

            return PopScope(
              canPop: !isForce,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                content: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check_circle_rounded,
                                size: 40, color: Colors.green)
                            : isFailed
                                ? const Icon(Icons.error_outline_rounded,
                                    size: 40, color: Colors.red)
                                : isDownloading
                                    ? SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value: progress,
                                              strokeWidth: 3.5,
                                              color: theme.colorScheme.primary,
                                            ),
                                            Text('$pct%',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme
                                                        .colorScheme.primary)),
                                          ],
                                        ),
                                      )
                                    : const Icon(Icons.system_update_rounded,
                                        size: 40, color: Colors.blue),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isCompleted
                            ? 'Download Complete'
                            : isFailed
                                ? 'Download Failed'
                                : isDownloading
                                    ? 'Downloading Update...'
                                    : 'Update Available',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isCompleted
                            ? 'Tap install to apply the update.'
                            : isFailed
                                ? _downloadProgress.error ??
                                    'Something went wrong.'
                                : isDownloading
                                    ? 'Downloading the latest version ($pct%)'
                                    : result.message ??
                                        'A new version is available.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      if (isDownloading) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$pct%  •  ${_formatSize(progress)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: isCompleted
                            ? ElevatedButton.icon(
                                onPressed: () {
                                  if (result.updateUrl != null) {
                                    _startDownload(service, result.updateUrl!);
                                  }
                                  Navigator.pop(ctx);
                                },
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.download_done_rounded,
                                    size: 18),
                                label: const Text('Install Now'),
                              )
                            : isFailed
                                ? ElevatedButton.icon(
                                    onPressed: () {
                                      if (result.updateUrl != null) {
                                        _startDownload(
                                            service, result.updateUrl!);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 18),
                                    label: const Text('Retry'),
                                  )
                                : isDownloading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5),
                                      )
                                    : ElevatedButton.icon(
                                        onPressed: () {
                                          if (result.updateUrl != null) {
                                            _startDownload(
                                                service, result.updateUrl!);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(Icons.download_rounded,
                                            size: 18),
                                        label: Text(
                                            isForce ? 'Update Now' : 'Update'),
                                      ),
                      ),
                      if (!isForce && !isDownloading && !isCompleted) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Later'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatSize(double fraction) {
    return '${(fraction * 100).toInt()}%';
  }
}

class _BlockingOverlay extends StatelessWidget {
  const _BlockingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.black54);
  }
}

class _MaintenanceOverlay extends StatelessWidget {
  final String? message;

  const _MaintenanceOverlay({this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build_rounded, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const Text('Under Maintenance',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),
            Text(
              message ?? 'We are currently performing scheduled maintenance.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
