import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/branding_provider.dart';

/// Branded Loading Widget
/// Shows organization logo during loading instead of Flutter logo
class BrandedLoading extends ConsumerWidget {
  final double size;
  final Color? backgroundColor;
  final bool showProgress;

  const BrandedLoading({
    super.key,
    this.size = 80,
    this.backgroundColor,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandingAsync = ref.watch(brandingProvider);
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.scaffoldBackgroundColor;

    return brandingAsync.when(
      loading: () => _buildDefaultLoading(theme),
      error: (_, __) => _buildDefaultLoading(theme),
      data: (branding) {
        if (branding.logoUrl == null || !branding.useCustomBranding) {
          return _buildDefaultLoading(theme);
        }

        // Check if we have cached logo bytes
        final cachedBytes = ref.read(brandingProvider.notifier).cachedLogoBytes;
        if (cachedBytes != null) {
          return _buildBrandedLoadingFromBytes(
            cachedBytes,
            branding,
            bgColor,
            theme,
          );
        }

        // Load from URL
        return FutureBuilder<Uint8List?>(
          future: _loadLogoFromUrl(branding.logoUrl!),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return _buildBrandedLoadingFromBytes(
                snapshot.data!,
                branding,
                bgColor,
                theme,
              );
            }
            return _buildDefaultLoading(theme);
          },
        );
      },
    );
  }

  Widget _buildDefaultLoading(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SizedBox(
              width: size * 0.6,
              height: size * 0.6,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms),
        if (showProgress) ...[
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBrandedLoadingFromBytes(
    Uint8List bytes,
    BrandingConfig branding,
    Color bgColor,
    ThemeData theme,
  ) {
    final primaryColor = Color(
      BrandingConfig.parseHexColor(branding.primaryColor) ?? 0xFF1976D2,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: size,
              height: size,
            ),
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.05, 1.05),
              duration: 1500.ms,
              curve: Curves.easeInOut,
            )
            .then()
            .scale(
              begin: const Offset(1.05, 1.05),
              end: const Offset(0.95, 0.95),
              duration: 1500.ms,
              curve: Curves.easeInOut,
            ),
        if (showProgress) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: size * 1.5,
            child: LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          branding.displayName ?? 'Loading...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Future<Uint8List?> _loadLogoFromUrl(String url) async {
    // This would use http package in production
    // For now, return null to use the cached bytes approach
    return null;
  }
}

/// Branded Splash Screen Widget
/// Used for app splash screen with organization branding
class BrandedSplashScreen extends ConsumerWidget {
  const BrandedSplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandingAsync = ref.watch(brandingProvider);
    final theme = Theme.of(context);

    return brandingAsync.when(
      loading: () => _buildDefaultSplash(theme),
      error: (_, __) => _buildDefaultSplash(theme),
      data: (branding) {
        if (!branding.useCustomBranding) {
          return _buildDefaultSplash(theme);
        }

        final primaryColor = Color(
          BrandingConfig.parseHexColor(branding.primaryColor) ?? 0xFF1976D2,
        );

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor.withValues(alpha: 0.1),
                primaryColor.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                BrandedLoading(size: 100),
                const SizedBox(height: 24),
                // Organization name
                if (branding.displayName != null)
                  Text(
                    branding.displayName!,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                if (branding.showPoweredBy) ...[
                  const SizedBox(height: 40),
                  Text(
                    'Powered by MicroFlow Pro',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultSplash(ThemeData theme) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance,
              size: 80,
              color: theme.colorScheme.primary,
            ).animate().scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 24),
            Text(
              'MicroFlow Pro',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Branded App Bar Logo
/// Shows organization logo in app bar
class BrandedAppBarLogo extends ConsumerWidget {
  final double height;

  const BrandedAppBarLogo({
    super.key,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandingAsync = ref.watch(brandingProvider);
    final theme = Theme.of(context);

    return brandingAsync.when(
      loading: () => _buildDefaultLogo(theme),
      error: (_, __) => _buildDefaultLogo(theme),
      data: (branding) {
        if (branding.logoUrl == null || !branding.useCustomBranding) {
          return _buildDefaultLogo(theme);
        }

        // Check cached bytes
        final cachedBytes = ref.read(brandingProvider.notifier).cachedLogoBytes;
        if (cachedBytes != null) {
          return Image.memory(
            cachedBytes,
            height: height,
            fit: BoxFit.contain,
          );
        }

        // Fallback to network image
        return Image.network(
          branding.logoUrl!,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildDefaultLogo(theme),
        );
      },
    );
  }

  Widget _buildDefaultLogo(ThemeData theme) {
    return Icon(
      Icons.account_balance,
      size: height,
      color: theme.colorScheme.primary,
    );
  }
}
