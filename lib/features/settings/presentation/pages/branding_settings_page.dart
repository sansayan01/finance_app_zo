import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/powered_by_badge.dart';
import '../../data/providers/brand_provider.dart';
import '../widgets/icon_preset_picker.dart';

class BrandingSettingsPage extends ConsumerStatefulWidget {
  const BrandingSettingsPage({super.key});

  @override
  ConsumerState<BrandingSettingsPage> createState() => _BrandingSettingsPageState();
}

class _BrandingSettingsPageState extends ConsumerState<BrandingSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _logoCtrl;
  late TextEditingController _colorCtrl;
  late String _selectedIconPreset;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final brand = ref.read(brandProvider);
    _nameCtrl = TextEditingController(text: brand.name);
    _logoCtrl = TextEditingController(text: brand.logoUrl ?? '');
    _colorCtrl = TextEditingController(text: brand.primaryColor ?? '#0066FF');
    _selectedIconPreset = brand.iconPreset;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _logoCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return AppColors.primary;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await ref.read(brandProvider.notifier).updateBrand(
            name: _nameCtrl.text.trim(),
            logoUrl: _logoCtrl.text.trim().isEmpty ? null : _logoCtrl.text.trim(),
            primaryColor: _colorCtrl.text.trim(),
            iconPreset: _selectedIconPreset,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Branding applied for all organization members'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update branding: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Live parsing color for real-time preview card
    final previewColor = _parseColor(_colorCtrl.text);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Branding Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'White-Label Customization',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 4),
                Text(
                  'Customize the brand assets that represent your organization to all members — '
                  'branch managers, staff, and customers.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                ).animate().fadeIn(delay: 50.ms),
                const SizedBox(height: 24),

                // ─── 1. LIVE PREVIEW CARD ────────────────────────────────
                Text(
                  'LIVE BRAND PREVIEW',
                  style: theme.textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: previewColor,
                  ),
                ).animate(delay: 100.ms).fadeIn(),
                const SizedBox(height: 8),
                _buildLivePreviewCard(theme, isDark, previewColor)
                    .animate(delay: 120.ms)
                    .fadeIn()
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 24),

                // ─── 2. BRANDING INPUT FORM ──────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.palette_outlined, color: previewColor),
                          const SizedBox(width: 12),
                          Text(
                            'Brand Assets',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Brand Name',
                          hintText: 'MicroFlow Pro',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _logoCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Logo URL (Network Image)',
                          hintText: 'https://example.com/logo.png',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _colorCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Primary Color (Hex)',
                          hintText: '#0066FF',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.color_lens_outlined),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: previewColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.24),
                              ),
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final match = RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$').hasMatch(v.trim());
                          return match ? null : 'Invalid Hex Format (e.g. #0066FF)';
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This color is used for action buttons, navigation indicators, '
                        'highlight headers, and structural UI elements across the app.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ).animate(delay: 150.ms).fadeIn(),

                const SizedBox(height: 24),

                // ─── 3. ICON PRESET PICKER ───────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: IconPresetPicker(
                    currentPreset: _selectedIconPreset,
                    onPresetSelected: (presetId) {
                      setState(() => _selectedIconPreset = presetId);
                    },
                  ),
                ).animate(delay: 180.ms).fadeIn(),

                const SizedBox(height: 32),

                // ─── 4. SAVE BUTTON ──────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _saving ? 'Applying to all members…' : 'Apply Brand Settings',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: previewColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ).animate(delay: 200.ms).fadeIn(),

                const SizedBox(height: 32),

                // ─── 5. POWERED BY BADGE ─────────────────────────────────
                const Center(child: PoweredByBadge())
                    .animate(delay: 250.ms)
                    .fadeIn(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard(ThemeData theme, bool isDark, Color brandColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Simulated App Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // Simulated Logo Placeholder
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: brandColor.withValues(alpha: 0.3)),
                  ),
                  child: _logoCtrl.text.trim().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _logoCtrl.text.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.business_rounded,
                              size: 16,
                              color: brandColor,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.business_rounded,
                          size: 16,
                          color: brandColor,
                        ),
                ),
                const SizedBox(width: 12),
                Text(
                  _nameCtrl.text.trim().isEmpty ? 'MicroFlow Pro' : _nameCtrl.text.trim(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.notifications_none_rounded,
                  size: 20,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ],
            ),
          ),

          // Simulated Repayment Card
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Outstanding Loan',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '₹ 45,620.00',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: brandColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Record Payment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'View Details',
                            style: TextStyle(
                              color: brandColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
