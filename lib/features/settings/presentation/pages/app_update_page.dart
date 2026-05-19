import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/providers/system_config_provider.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

class AppUpdatePage extends ConsumerStatefulWidget {
  const AppUpdatePage({super.key});

  @override
  ConsumerState<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends ConsumerState<AppUpdatePage> {
  final _versionCtrl = TextEditingController();
  final _minVersionCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final config = await ref.read(systemConfigProvider.future);
      _versionCtrl.text = config.currentVersionAndroid;
      _minVersionCtrl.text = config.minVersionAndroid;
      _messageCtrl.text = config.updateMessage;
    });
  }

  @override
  void dispose() {
    _versionCtrl.dispose();
    _minVersionCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
      allowMultiple: false,
      withData: kIsWeb, // Only load bytes on web
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _error = null;
      });
    }
  }

  /// Read file bytes — handles both web (bytes) and mobile (path)
  Future<Uint8List?> _getFileBytes() async {
    if (_selectedFile == null) return null;

    // On web, bytes are available directly
    if (_selectedFile!.bytes != null) {
      return _selectedFile!.bytes!;
    }

    // On mobile, read from path
    if (_selectedFile!.path != null) {
      final file = File(_selectedFile!.path!);
      return await file.readAsBytes();
    }

    return null;
  }

  Future<void> _publishUpdate() async {
    if (_versionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a version number');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _error = null;
      _success = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      String? downloadUrl;

      if (_selectedFile != null) {
        final fileBytes = await _getFileBytes();
        if (fileBytes == null) {
          setState(() {
            _error = 'Could not read the selected file.';
            _isUploading = false;
          });
          return;
        }

        setState(() => _uploadProgress = 0.1);

        const filePath = 'apk/microflow-latest.apk';

        // Upload the APK to Supabase Storage
        await client.storage.from('app-updates').uploadBinary(
              filePath,
              fileBytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'application/vnd.android.package-archive',
              ),
            );

        setState(() => _uploadProgress = 0.8);

        downloadUrl =
            client.storage.from('app-updates').getPublicUrl(filePath);
      }

      setState(() => _uploadProgress = 0.9);

      // Update system_config with new version info
      final updates = <String, dynamic>{
        'current_version_android': _versionCtrl.text.trim(),
        'min_version_android': _minVersionCtrl.text.trim().isNotEmpty
            ? _minVersionCtrl.text.trim()
            : _versionCtrl.text.trim(),
        'update_message': _messageCtrl.text.trim().isNotEmpty
            ? _messageCtrl.text.trim()
            : 'A new version is available. Please update to continue.',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (downloadUrl != null) {
        updates['update_url_android'] = downloadUrl;
      }

      final config = await ref.read(systemConfigProvider.future);
      await client
          .from('system_config')
          .update(updates)
          .eq('id', config.id ?? '');

      setState(() => _uploadProgress = 1.0);

      // Invalidate providers so the app picks up the new version
      ref.invalidate(systemConfigProvider);
      ref.invalidate(updateCheckProvider);

      setState(() {
        _success =
            '✅ Version ${_versionCtrl.text.trim()} published successfully!';
        _selectedFile = null;
      });
    } catch (e) {
      debugPrint('❌ Publish error: $e');
      setState(() => _error = 'Failed to publish: $e');
    } finally {
      setState(() => _isUploading = false);
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
        title: Text('App Updates',
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

            // Version info card
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
                      Text('Version Info',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _versionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New Version *',
                      hintText: 'e.g. 1.0.1',
                      prefixIcon: Icon(Icons.new_releases_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _minVersionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Required Version',
                      hintText: 'Users below this will be forced to update',
                      prefixIcon: Icon(Icons.security_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If min version = new version → force update. If min version < new version → soft update (user can skip).',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[500], fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Release Notes / Update Message',
                      hintText: 'What\'s new in this version?',
                      prefixIcon: Icon(Icons.notes_rounded, size: 20),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 20),

            // APK upload card
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.android_rounded,
                          color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Text('APK File',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload the latest APK. The old file is automatically replaced.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _isUploading ? null : _pickFile,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedFile != null
                              ? Colors.green
                              : Colors.grey.withValues(alpha: 0.3),
                          width: _selectedFile != null ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: _selectedFile != null
                            ? Colors.green.withValues(alpha: 0.05)
                            : null,
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              _selectedFile != null
                                  ? Icons.check_circle_outline
                                  : Icons.cloud_upload_outlined,
                              size: 36,
                              color: _selectedFile != null
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFile != null
                                  ? _selectedFile!.name
                                  : 'Tap to select APK file',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color:
                                    _selectedFile != null ? Colors.green : null,
                              ),
                            ),
                            if (_selectedFile != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${(_selectedFile!.size / 1048576).toStringAsFixed(1)} MB',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isUploading) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(_uploadProgress * 100).toInt()}% uploading...',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _publishUpdate,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.publish_rounded),
                      label: Text(_isUploading
                          ? 'Uploading & Publishing...'
                          : 'Publish Update'),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard(ThemeData theme) {
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
                    Text('Current Published Version',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow('Android Version', config.currentVersionAndroid),
                _infoRow('Min Required', config.minVersionAndroid),
                _infoRow(
                    'Has APK URL', config.updateUrlAndroid != null ? '✅' : '❌'),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading config: $e'),
        );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
