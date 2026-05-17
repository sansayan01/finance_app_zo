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
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  Future<void> _publishUpdate() async {
    if (_versionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a version number');
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
      _success = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      String? downloadUrl;

      if (_selectedFile != null && _selectedFile!.bytes != null) {
        final filePath = 'apk/microflow-latest.apk';

        await client.storage.from('app-updates').uploadBinary(
              filePath,
              _selectedFile!.bytes!,
              fileOptions: const FileOptions(
                  upsert: true,
                  contentType: 'application/vnd.android.package-archive'),
            );

        downloadUrl = client.storage.from('app-updates').getPublicUrl(filePath);
      }

      final updates = <String, dynamic>{
        'current_version_android': _versionCtrl.text.trim(),
        'min_version_android': _minVersionCtrl.text.trim().isNotEmpty
            ? _minVersionCtrl.text.trim()
            : _versionCtrl.text.trim(),
        'update_message': _messageCtrl.text.trim().isNotEmpty
            ? _messageCtrl.text.trim()
            : 'A new version is available. Please update to continue.',
      };

      if (downloadUrl != null) {
        updates['update_url_android'] = downloadUrl;
      }

      await client
          .from('system_config')
          .update(updates)
          .eq('id', (await ref.read(systemConfigProvider.future)).id ?? '');

      ref.invalidate(systemConfigProvider);
      ref.invalidate(updateCheckProvider);

      setState(() {
        _success = 'Version ${_versionCtrl.text.trim()} published!';
        _selectedFile = null;
      });
    } catch (e) {
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
            Text(
              'Publish a new APK. The old file is automatically replaced.',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
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
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Version Info',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _versionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New Version *',
                      hintText: 'e.g. 1.0.1',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _minVersionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Required Version',
                      hintText: 'Leave same as version for soft update',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Update Message',
                      hintText: 'What\'s new in this version?',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 20),
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('APK File',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _pickFile,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedFile != null
                              ? Colors.green
                              : Colors.grey.withValues(alpha: 0.3),
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(12),
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
                                  : 'Tap to select APK',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color:
                                    _selectedFile != null ? Colors.green : null,
                              ),
                            ),
                            if (_selectedFile != null)
                              Text(
                                '${(_selectedFile!.size / 1048576).toStringAsFixed(1)} MB',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
}
