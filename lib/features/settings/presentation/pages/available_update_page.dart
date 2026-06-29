import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:microflow_pro/core/models/app_update.dart';
import 'package:microflow_pro/core/providers/system_config_provider.dart';
import 'package:microflow_pro/core/services/app_update_service.dart';
import 'package:microflow_pro/core/widgets/glass_card.dart';
import 'package:microflow_pro/features/settings/data/providers/app_update_provider.dart';

class AvailableUpdatePage extends ConsumerStatefulWidget {
  const AvailableUpdatePage({super.key});

  @override
  ConsumerState<AvailableUpdatePage> createState() => _AvailableUpdatePageState();
}

class _AvailableUpdatePageState extends ConsumerState<AvailableUpdatePage> {
  final AppUpdateService _svc = AppUpdateService();
  DownloadProgress _dl = const DownloadProgress();

  @override
  void initState() {
    super.initState();
    _svc.progressStream.listen((p) {
      if (mounted) setState(() => _dl = p);
    });
  }

  @override
  void dispose() {
    _svc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(systemConfigProvider).valueOrNull;
    final updateAsync = ref.watch(androidUpdateStatusProvider);

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

          // ── Update card from stream ─────────────────────────────────
          updateAsync.when(
            data: (result) {
              final row = result.update;
              if (row == null) return _noUpdateCard(theme);
              return _buildCard(theme, row, config);
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

          const SizedBox(height: 20),

          // ── Maintenance toggle ───────────────────────────────────────
          if (config != null) _buildMaintenanceCard(theme, config),

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
        ],
      );

  Widget _noUpdateCard(ThemeData theme) => GlassCard(
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
          ],
        ),
      );

  Widget _buildCard(
      ThemeData theme, AppUpdate row, dynamic config) {
    final isForce = row.isCritical;
    final isDone = _dl.state == DownloadState.completed;
    final isFail = _dl.state == DownloadState.failed;
    final isBusy = _dl.state == DownloadState.downloading;
    final pct = (_dl.progress * 100).toInt();

    String sizeLabel = '—';
    if (row.fileSizeMb != null) {
      final mb = row.fileSizeMb!;
      sizeLabel =
          mb >= 1 ? '${mb.toStringAsFixed(1)} MB' : '${(mb * 1024).toStringAsFixed(0)} KB';
    }

    String agoLabel;
    try {
      final diff = DateTime.now().difference(row.publishedAt);
      agoLabel = diff.inDays > 0
          ? '${diff.inDays}d ago'
          : diff.inHours > 0
              ? '${diff.inHours}h ago'
              : 'Just now';
    } catch (_) {
      agoLabel = '';
    }

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.new_releases_rounded,
                  color: isForce ? Colors.red : Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text('v${row.version}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isForce
                      ? Colors.red.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isForce ? 'Must Update' : 'Recommended',
                  style: TextStyle(
                    color: isForce ? Colors.red : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (row.releaseNotes != null && row.releaseNotes!.isNotEmpty) ...[
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
                row.releaseNotes!,
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
              _chip(Icons.schedule_rounded, agoLabel),
              if (sizeLabel != '—') _chip(Icons.storage_rounded, sizeLabel),
              _chip(
                  Icons.link_rounded, row.downloadUrl.isEmpty ? 'N/A' : 'APK Ready'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isBusy
                  ? null
                  : () async {
                      HapticFeedback.mediumImpact();
                      if (!mounted) return;
                      await _svc.downloadAndInstall(row.downloadUrl);
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
                backgroundColor: isForce ? Colors.red : null,
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
              label: Text(_btnLabel(isDone, isFail, isBusy, isForce, pct)),
            ),
          ),
          if (isFail && _dl.error != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => _svc.downloadAndInstall(row.downloadUrl),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ),
            Text(_dl.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(ThemeData theme, dynamic config) {
    final isDown = config.isUnderMaintenance as bool;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.engineering_rounded,
                  color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text('Maintenance Mode',
                  style:
                      theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Toggle puts the app into read-only mode for all users.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: isDown,
            onChanged: (_) {},
            title: Text(isDown ? 'Maintenance ON' : 'Maintenance OFF'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              // call maintenance service in a moment
            },
            icon: Icon(isDown ? Icons.play_arrow_rounded : Icons.pause_rounded),
            label: Text(isDown ? 'Resume Service' : 'Pause Service'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              backgroundColor: isDown ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
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

  String _btnLabel(bool done, bool fail, bool busy, bool force, int pct) =>
      done
          ? 'Install Now'
          : fail
              ? 'Retry'
              : busy
                  ? '$pct%'
                  : force
                      ? 'Update Now'
                      : 'Download & Install';
}
