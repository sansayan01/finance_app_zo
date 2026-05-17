import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/providers/branding_providers.dart';
import '../../models/org_branding_model.dart';

class BrandingSettingsPage extends ConsumerStatefulWidget {
  final String orgId;

  const BrandingSettingsPage({super.key, required this.orgId});

  @override
  ConsumerState<BrandingSettingsPage> createState() =>
      _BrandingSettingsPageState();
}

class _BrandingSettingsPageState extends ConsumerState<BrandingSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _primaryColorController;
  late TextEditingController _secondaryColorController;
  late TextEditingController _accentColorController;
  late TextEditingController _loginTitleController;
  late TextEditingController _loginSubtitleController;
  late TextEditingController _customDomainController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _primaryColorController = TextEditingController(text: '#3B82F6');
    _secondaryColorController = TextEditingController(text: '#1E40AF');
    _accentColorController = TextEditingController(text: '#10B981');
    _loginTitleController = TextEditingController();
    _loginSubtitleController = TextEditingController();
    _customDomainController = TextEditingController();
  }

  @override
  void dispose() {
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _accentColorController.dispose();
    _loginTitleController.dispose();
    _loginSubtitleController.dispose();
    _customDomainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandingAsync = ref.watch(brandingNotifierProvider(widget.orgId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branding Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveChanges,
          ),
        ],
      ),
      body: brandingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (branding) {
          if (branding != null) {
            _primaryColorController.text = branding.primaryColor;
            _secondaryColorController.text = branding.secondaryColor;
            _accentColorController.text = branding.accentColor;
            _loginTitleController.text = branding.loginTitle ?? '';
            _loginSubtitleController.text = branding.loginSubtitle ?? '';
            _customDomainController.text = branding.customDomain ?? '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo Section
                  _buildSectionHeader('Logo & Icons', Icons.image, theme),
                  const SizedBox(height: 16),
                  _buildLogoUploadCard(branding, theme),
                  const SizedBox(height: 32),

                  // Colors Section
                  _buildSectionHeader('Brand Colors', Icons.palette, theme),
                  const SizedBox(height: 16),
                  _buildColorsCard(theme),
                  const SizedBox(height: 32),

                  // Login Page Section
                  _buildSectionHeader('Login Page', Icons.login, theme),
                  const SizedBox(height: 16),
                  _buildLoginPageCard(branding, theme),
                  const SizedBox(height: 32),

                  // Custom Domain Section
                  _buildSectionHeader('Custom Domain', Icons.domain, theme),
                  const SizedBox(height: 16),
                  _buildCustomDomainCard(branding, theme),
                  const SizedBox(height: 32),

                  // Features Section
                  _buildSectionHeader('Features', Icons.star, theme),
                  const SizedBox(height: 16),
                  _buildFeaturesCard(branding, theme),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, color: theme.primaryColor),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoUploadCard(OrgBrandingModel? branding, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Preview
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Logo (Light)', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 12),
                      Container(
                        width: 120,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: branding?.logoUrl != null
                            ? Image.network(branding!.logoUrl!,
                                fit: BoxFit.contain)
                            : const Icon(Icons.image,
                                size: 40, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _uploadLogo(isDark: false),
                        icon: const Icon(Icons.upload),
                        label: const Text('Upload'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      Text('Logo (Dark)', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 12),
                      Container(
                        width: 120,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          border: Border.all(color: Colors.grey[700]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: branding?.logoDarkUrl != null
                            ? Image.network(branding!.logoDarkUrl!,
                                fit: BoxFit.contain)
                            : const Icon(Icons.image,
                                size: 40, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _uploadLogo(isDark: true),
                        icon: const Icon(Icons.upload),
                        label: const Text('Upload'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildColorField('Primary Color', _primaryColorController),
            const SizedBox(height: 16),
            _buildColorField('Secondary Color', _secondaryColorController),
            const SizedBox(height: 16),
            _buildColorField('Accent Color', _accentColorController),
            const SizedBox(height: 16),
            // Color Preview
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Preview', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(int.parse(
                              _primaryColorController.text
                                  .replaceFirst('#', 'FF'),
                              radix: 16)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Button Text',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorField(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || !v.startsWith('#') || v.length != 7) {
                return 'Invalid hex color (e.g., #3B82F6)';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () async {
            final color = await _pickColor(controller.text);
            if (color != null) {
              setState(() {
                controller.text = color;
              });
            }
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(int.parse(controller.text.replaceFirst('#', 'FF'),
                  radix: 16)),
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPageCard(OrgBrandingModel? branding, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextFormField(
              controller: _loginTitleController,
              decoration: const InputDecoration(
                labelText: 'Login Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loginSubtitleController,
              decoration: const InputDecoration(
                labelText: 'Login Subtitle',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Preview
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (_loginTitleController.text.isNotEmpty)
                    Text(
                      _loginTitleController.text,
                      style: theme.textTheme.headlineSmall,
                    ),
                  if (_loginSubtitleController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _loginSubtitleController.text,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDomainCard(OrgBrandingModel? branding, ThemeData theme) {
    final isVerified = branding?.domainVerified ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _customDomainController,
              decoration: InputDecoration(
                labelText: 'Custom Domain',
                hintText: 'app.yourcompany.com',
                border: const OutlineInputBorder(),
                suffixIcon: isVerified
                    ? const Icon(Icons.verified, color: Colors.green)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            if (_customDomainController.text.isNotEmpty && !isVerified) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DNS Verification Required',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add this TXT record to your DNS:',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'microflow-verify=${branding?.customDomain ?? ""}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _verifyDomain,
                      child: const Text('Verify Domain'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesCard(OrgBrandingModel? branding, ThemeData theme) {
    final features = branding?.features ?? {};

    final featureList = [
      {'key': 'chatbot', 'name': 'Smart Assistant', 'icon': Icons.chat},
      {
        'key': 'analytics',
        'name': 'Advanced Analytics',
        'icon': Icons.analytics
      },
      {'key': 'api_access', 'name': 'API Access', 'icon': Icons.api},
      {
        'key': 'white_label',
        'name': 'White Label',
        'icon': Icons.branding_watermark
      },
      {'key': 'custom_domain', 'name': 'Custom Domain', 'icon': Icons.domain},
      {'key': 'sso', 'name': 'SSO (SAML)', 'icon': Icons.login},
      {'key': 'audit_logs', 'name': 'Audit Logs', 'icon': Icons.history},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: featureList.map((feature) {
            final isEnabled = features[feature['key']] == true;
            return SwitchListTile(
              title: Text(feature['name'] as String),
              secondary: Icon(feature['icon'] as IconData),
              value: isEnabled,
              onChanged: (v) => _toggleFeature(feature['key'] as String, v),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _uploadLogo({bool isDark = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final notifier =
            ref.read(brandingNotifierProvider(widget.orgId).notifier);
        await notifier.uploadLogo(
          file.name,
          file.bytes!,
          isDark: isDark,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo uploaded successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<String?> _pickColor(String currentColor) async {
    // Simple color picker - in production, use a color picker package
    final colors = [
      '#3B82F6',
      '#EF4444',
      '#10B981',
      '#F59E0B',
      '#8B5CF6',
      '#EC4899',
      '#06B6D4',
      '#84CC16',
      '#F97316',
      '#6366F1',
    ];

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors
              .map((c) => GestureDetector(
                    onTap: () => Navigator.pop(ctx, c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(
                            int.parse(c.replaceFirst('#', 'FF'), radix: 16)),
                        border: Border.all(
                          color: currentColor == c
                              ? Colors.black
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _verifyDomain() async {
    setState(() => _isLoading = true);
    try {
      final notifier =
          ref.read(brandingNotifierProvider(widget.orgId).notifier);
      final success = await notifier.verifyCustomDomain();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Domain verified!' : 'Verification failed'),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFeature(String key, bool value) async {
    final notifier = ref.read(brandingNotifierProvider(widget.orgId).notifier);
    await notifier.updateFeatures({key: value});
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final notifier =
          ref.read(brandingNotifierProvider(widget.orgId).notifier);
      await notifier.updateBranding({
        'primary_color': _primaryColorController.text,
        'secondary_color': _secondaryColorController.text,
        'accent_color': _accentColorController.text,
        'login_title': _loginTitleController.text,
        'login_subtitle': _loginSubtitleController.text,
        'custom_domain': _customDomainController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branding updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
