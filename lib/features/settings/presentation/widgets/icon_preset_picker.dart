import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/services/app_icon_service.dart';

/// A grid picker that lets the executive admin choose a preset launcher icon
/// for the organization. The selected preset is applied to all org members.
class IconPresetPicker extends StatelessWidget {
  final String currentPreset;
  final ValueChanged<String> onPresetSelected;

  const IconPresetPicker({
    super.key,
    required this.currentPreset,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.app_settings_alt_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Home Screen Icon Theme',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a launcher icon for all organization members. '
          'This changes the app icon and name on everyone\'s phone home screen.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: IconPresets.all.length,
          itemBuilder: (context, index) {
            final preset = IconPresets.all[index];
            final isSelected = preset.id == currentPreset;

            return _IconPresetTile(
              preset: preset,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () => onPresetSelected(preset.id),
            ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn().scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1, 1),
                );
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Icon changes may take a few seconds to appear on the home screen. '
                  'All org members will see the change on their next app launch.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconPresetTile extends StatelessWidget {
  final IconPreset preset;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _IconPresetTile({
    required this.preset,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final presetColor = Color(preset.colorValue);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? presetColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E2230) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? presetColor : Colors.transparent,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: presetColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon preview circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    presetColor,
                    presetColor.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: presetColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              preset.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? presetColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: presetColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
