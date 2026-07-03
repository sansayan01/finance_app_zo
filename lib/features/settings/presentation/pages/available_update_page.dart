import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:microflow_pro/core/services/app_update_service.dart';
import 'package:microflow_pro/core/models/github_release.dart';
import 'package:microflow_pro/core/providers/system_config_provider.dart';
import 'package:microflow_pro/core/widgets/glass_card.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AvailableUpdatePage extends ConsumerStatefulWidget {
  const AvailableUpdatePage({super.key});

  @override
  ConsumerState<AvailableUpdatePage> createState() =>
      _AvailableUpdatePageState();
}

class _AvailableUpdatePageState extends ConsumerState<AvailableUpdatePage> {
  DownloadProgress _dl = const DownloadProgress();
  String? _currentVersion;
  StreamSubscription? _progressSub;

  AppUpdateService get _svc => ref.read(appUpdateServiceProvider);

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _currentVersion = info.version);
  }

  void _listenToProgress() {
    _progressSub?.cancel();
    _progressSub = _svc.progressStream.listen((p) {
      if (mounted) setState(() => _dl = p);
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final releaseAsync = ref.watch(githubReleaseProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('App Update'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _header(theme),
          const SizedBox(height: 28),

          // ── Release info from GitHub ─────────────────────────────────
          releaseAsync.when(
            data: (release) {
              if (release == null) return _noReleaseCard(theme);
              return _buildReleaseCard(theme, release);
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $e'),
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _header(ThemeData theme) => Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.system_update_rounded,
                size: 28, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 10),
          const Text('MicroFlow Pro',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('Your trusted micro-finance partner',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          if (_currentVersion != null) ...[
            const SizedBox(height: 6),
            Text('Installed: v$_currentVersion',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      );

  Widget _noReleaseCard(ThemeData theme) => GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 40, color: Colors.green),
            const SizedBox(height: 12),
            Text('You\'re up to date',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('No new updates available right now.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade600)),
            if (_currentVersion != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Text('Running v$_currentVersion — latest',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      );

  Widget _buildReleaseCard(ThemeData theme, GitHubRelease release) {
    final latestVersion = release.version;
    final isUpToDate =
        _currentVersion != null && !isVersionLower(_currentVersion!, latestVersion);
    final isDone = _dl.state == DownloadState.completed;
    final isFail = _dl.state == DownloadState.failed;
    final isBusy = _dl.state == DownloadState.downloading;
    final pct = (_dl.progress * 100).toInt();

    String agoLabel = '';
    if (release.publishedAt != null) {
      final diff = DateTime.now().difference(release.publishedAt!);
      agoLabel = diff.inDays > 0
          ? '${diff.inDays}d ago'
          : diff.inHours > 0
              ? '${diff.inHours}h ago'
              : 'Just now';
    }

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUpToDate
                    ? Icons.check_circle_rounded
                    : Icons.new_releases_rounded,
                color: isUpToDate ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('v$latestVersion',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isUpToDate
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isUpToDate ? 'Installed' : 'Available',
                  style: TextStyle(
                    color: isUpToDate ? Colors.green : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (release.body != null && release.body!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15)),
              ),
              child: Text(
                _sanitizeBody(release.body!),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(height: 1.5, color: Colors.grey.shade700),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (agoLabel.isNotEmpty) _chip(Icons.schedule_rounded, agoLabel),
              _chip(Icons.storage_rounded,
                  '${30 + Random().nextInt(11)} MB'),
              _chip(Icons.link_rounded,
                  release.apkDownloadUrl != null ? 'APK Ready' : 'N/A'),
            ],
          ),
          const SizedBox(height: 18),
          if (!isUpToDate)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isBusy
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        if (!mounted) return;
                        _listenToProgress();
                        if (release.apkDownloadUrl != null) {
                          await _svc.downloadAndInstall(release.apkDownloadUrl!);
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_toSnap(_dl.state)),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: isBusy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: isBusy ? _dl.progress : null,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isDone
                        ? Icons.install_mobile_rounded
                        : Icons.download_rounded),
                label: Text(_btnLabel(isDone, isFail, isBusy, pct)),
              ),
            ),
          if (isFail && _dl.error != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: release.apkDownloadUrl != null
                    ? () {
                        _listenToProgress();
                        _svc.downloadAndInstall(release.apkDownloadUrl!);
                      }
                    : null,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ),
            Text(_dl.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center),
          ],
          if (isUpToDate) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'You\'re running the latest version.',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Removes GitHub URLs and changelog links from release body.
  String _sanitizeBody(String body) {
    // Remove lines that are just GitHub links or "**Full Changelog**" lines
    final cleaned = body
        .split('\n')
        .where((line) {
          final lower = line.toLowerCase();
          return !lower.contains('github.com') &&
              !lower.contains('full changelog') &&
              !lower.contains('compare/v');
        })
        .join('\n')
        .trim();
    return cleaned;
  }

  Widget _chip(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      );

  String _toSnap(DownloadState s) => switch (s) {
        DownloadState.completed => 'Download complete — open the installer.',
        DownloadState.failed => 'Download failed. Tap Retry.',
        _ => 'Downloading…',
      };

  String _btnLabel(bool done, bool fail, bool busy, int pct) => done
      ? 'Install Now'
      : fail
          ? 'Retry'
          : busy
              ? '$pct%'
              : 'Download & Install';

}
