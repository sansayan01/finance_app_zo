import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/services/github_release_service.dart';
import '../../../../core/models/github_release.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/providers/system_config_provider.dart';

class AppUpdatePage extends ConsumerStatefulWidget {
  const AppUpdatePage({super.key});

  @override
  ConsumerState<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends ConsumerState<AppUpdatePage> {
  final _minVersionCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSaving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final config = await ref.read(systemConfigProvider.future);
      _minVersionCtrl.text = config.minVersionAndroid;
      _messageCtrl.text = config.updateMessage;
    });
  }

  @override
  void dispose() {
    _minVersionCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _publishUpdate() async {
    setState(() {
      _isSaving = true;
      _error = null;
      _success = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);

      final updates = <String, dynamic>{
        'min_version_android': _minVersionCtrl.text.trim(),
        'update_message': _messageCtrl.text.trim().isNotEmpty
            ? _messageCtrl.text.trim()
            : 'A new version is available. Please update to continue.',
        'is_under_maintenance': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final config = await ref.read(systemConfigProvider.future);
      await client
          .from('system_config')
          .update(updates)
          .eq('id', config.id ?? '');

      ref.invalidate(systemConfigProvider);

      setState(() {
        _success = '✅ Release configuration saved!';
      });
    } catch (e) {
      debugPrint('❌ Publish error: $e');
      setState(() => _error = 'Failed to save: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Release Configuration',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current status card
            _buildCurrentStatusCard(theme),
            const SizedBox(height: 24),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),
            if (_success != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_success!,
                            style: const TextStyle(
                                color: Colors.green, fontSize: 13))),
                  ],
                ),
              ),

            // Version constraint card
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tag_rounded,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Version Constraints',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _minVersionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Required Version',
                      hintText: 'e.g. 1.0.8 — users below this are forced to update',
                      prefixIcon: Icon(Icons.security_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Users running a version older than this will be forced to update. Leave empty to allow all versions.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[500], fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Update Message',
                      hintText: 'What\'s new? Shown in the update dialog.',
                      prefixIcon: Icon(Icons.notes_rounded, size: 20),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 20),

            // Publish button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _publishUpdate,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
              ),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard(ThemeData theme) {
    final releaseService = ref.read(githubReleaseServiceProvider);

    return FutureBuilder<GitHubRelease?>(
      future: releaseService.fetchLatestRelease(),
      builder: (context, snapshot) {
        final release = snapshot.data;

        return ref.watch(systemConfigProvider).when(
              data: (config) => GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Release Status',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (release != null) ...[
                      _infoRow('Latest GitHub Release', release.version),
                      _infoRow(
                        'Published',
                        release.publishedAt != null
                            ? _formatDate(release.publishedAt!)
                            : 'Unknown',
                      ),
                      _infoRow(
                        'APK Available',
                        release.apkDownloadUrl != null ? '✅' : '❌',
                      ),
                    ] else if (snapshot.connectionState ==
                        ConnectionState.waiting) ...[
                      _infoRow('Latest GitHub Release', 'Loading...'),
                    ] else ...[
                      _infoRow('Latest GitHub Release', 'Unavailable'),
                    ],
                    const Divider(height: 20),
                    _infoRow('Min Required', config.minVersionAndroid.isNotEmpty
                        ? config.minVersionAndroid
                        : 'None'),
                    _infoRow('Maintenance', config.isUnderMaintenance ? '🔴 ON' : '🟢 OFF'),
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading config: $e'),
            );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
