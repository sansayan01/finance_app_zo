import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/layout.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/customer_biometric_providers.dart';
import '../../data/providers/customer_notification_preferences_provider.dart';
import '../../data/providers/customer_profile_providers.dart';

class CustomerAccountSettingsPage extends ConsumerStatefulWidget {
  const CustomerAccountSettingsPage({super.key});

  @override
  ConsumerState<CustomerAccountSettingsPage> createState() =>
      _CustomerAccountSettingsPageState();
}

class _CustomerAccountSettingsPageState
    extends ConsumerState<CustomerAccountSettingsPage>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Animation<double> _staggered(int index) {
    final start = (index * 0.07).clamp(0.0, 1.0);
    final end = (start + 0.42).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  Widget _animatedEntry(int index, Widget child) {
    return AnimatedBuilder(
      animation: _staggered(index),
      builder: (context, child) => Opacity(
        opacity: _staggered(index).value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - _staggered(index).value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(customerProfileProvider);
    final profile = profileAsync.valueOrNull;

    final kycStatus = (profile?.kycStatus ?? '').toLowerCase();
    final kycLabel = kycStatus == 'verified'
        ? 'Verified'
        : kycStatus == 'rejected'
            ? 'Rejected'
            : 'Pending';
    final kycColor = kycStatus == 'verified'
        ? AppColors.success
        : kycStatus == 'rejected'
            ? AppColors.error
            : AppColors.warning;
    final roleLabel = user?.role?.name ?? 'customer';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium sliver app bar with blur
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 14),
              title: Text(
                'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                            : [AppColors.primary.withValues(alpha: 0.05), AppColors.accent.withValues(alpha: 0.05)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    bottom: -40,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.06),
                      ),
                    ),
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(color: Colors.transparent),
                  ),
                ],
              ),
            ),
          ),

          // Profile summary
          SliverToBoxAdapter(
            child: _animatedEntry(
              0,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _buildProfileSummary(
                  context, isDark, user, kycLabel, kycColor, roleLabel,
                ),
              ),
            ),
          ),

          // Security section
          SliverToBoxAdapter(
            child: _animatedEntry(
              1,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _buildSectionHeader(
                    context, 'Security', Icons.shield_rounded, isDark),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _animatedEntry(
              2,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _buildSecuritySection(context, isDark),
              ),
            ),
          ),

          // Appearance section
          SliverToBoxAdapter(
            child: _animatedEntry(
              3,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _buildSectionHeader(
                    context, 'Appearance', Icons.palette_rounded, isDark),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _animatedEntry(
              4,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _buildAppearanceSection(context, isDark),
              ),
            ),
          ),

          // Notifications section
          SliverToBoxAdapter(
            child: _animatedEntry(
              5,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _buildSectionHeader(context, 'Notifications',
                    Icons.notifications_rounded, isDark),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _animatedEntry(
              6,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _buildNotificationsSection(context, isDark),
              ),
            ),
          ),

          // About section
          SliverToBoxAdapter(
            child: _animatedEntry(
              7,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _buildSectionHeader(
                    context, 'About', Icons.info_rounded, isDark),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _animatedEntry(
              8,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _buildAboutSection(context, isDark),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    ),
    );
  }

  Widget _buildProfileSummary(
    BuildContext context,
    bool isDark,
    dynamic user,
    String kycLabel,
    Color kycColor,
    String roleLabel,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1E2D).withValues(alpha: 0.9), const Color(0xFF161622).withValues(alpha: 0.8)]
              : [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    // Glowing profile avatar container
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (user?.fullName?.isNotEmpty == true)
                              ? user!.fullName![0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'User',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              color: (isDark ? Colors.white : const Color(0xFF0F172A))
                                  .withValues(alpha: 0.55),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(
                  height: 1,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildProfileStat(
                      label: 'KYC Status',
                      value: kycLabel,
                      valueColor: kycColor,
                      isDark: isDark,
                    ),
                    _buildProfileStat(
                      label: 'Member Role',
                      value: roleLabel,
                      valueColor: AppColors.info,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStat({
    required String label,
    required String value,
    required Color valueColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: (isDark ? Colors.white : const Color(0xFF0F172A)).withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.14),
                AppColors.accent.withValues(alpha: isDark ? 0.20 : 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppColors.primary, size: 17),
        ),
        const SizedBox(width: 11),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(BuildContext context, bool isDark) {
    final biometricAsync = ref.watch(customerBiometricEnabledProvider);
    final biometricLabel = ref.watch(customerBiometricLabelProvider);
    final biometricAvailable = ref.watch(customerBiometricAvailableProvider);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Biometric login
          biometricAvailable.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (available) {
              if (!available) return const SizedBox.shrink();
              return Column(
                children: [
                  _buildToggleTile(
                    context,
                    isDark,
                    icon: Icons.fingerprint_rounded,
                    iconColor: AppColors.success,
                    title: 'Biometric Login',
                    subtitle: biometricLabel.when(
                      loading: () => 'Checking...',
                      error: (_, __) => 'Biometric',
                      data: (label) => label,
                    ),
                    value: biometricAsync.when(
                      loading: () => false,
                      error: (_, __) => false,
                      data: (enabled) => enabled,
                    ),
                    onChanged: (val) async {
                      HapticFeedback.lightImpact();
                      await ref
                          .read(customerBiometricToggleProvider.notifier)
                          .toggle(val);
                    },
                  ),
                  _buildDivider(isDark),
                ],
              );
            },
          ),

          // Change password
          _buildNavigationTile(
            context,
            isDark,
            icon: Icons.lock_rounded,
            iconColor: AppColors.info,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () => _showChangePasswordSheet(context, isDark),
          ),
          _buildDivider(isDark),

          // 2FA (coming soon)
          _buildNavigationTile(
            context,
            isDark,
            icon: Icons.verified_user_rounded,
            iconColor: AppColors.warning,
            title: 'Two-Factor Authentication',
            subtitle: 'Coming soon',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Soon',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context, bool isDark) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        children: [
          // Light Theme Button
          Expanded(
            child: _buildThemeOptionCard(
              context: context,
              label: 'Light Mode',
              icon: Icons.light_mode_rounded,
              isSelected: !isDarkMode,
              activeColor: AppColors.orange,
              isDarkCard: false,
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(themeProvider.notifier).setThemeMode(ThemeMode.light);
              },
            ),
          ),
          const SizedBox(width: 16),
          // Dark Theme Button
          Expanded(
            child: _buildThemeOptionCard(
              context: context,
              label: 'Dark Mode',
              icon: Icons.dark_mode_rounded,
              isSelected: isDarkMode,
              activeColor: AppColors.primary,
              isDarkCard: true,
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOptionCard({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required bool isDarkCard,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shadowColor = isSelected ? activeColor.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isDarkCard 
            ? const Color(0xFF1E1E2D).withValues(alpha: isDark ? 0.95 : 0.8) 
            : Colors.white.withValues(alpha: isDark ? 0.8 : 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected 
              ? activeColor 
              : (isDarkCard ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: isSelected ? 12 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? activeColor.withValues(alpha: 0.15) 
                          : (isDarkCard ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? activeColor : (isDarkCard ? Colors.white54 : Colors.black45),
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isDarkCard ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context, bool isDark) {
    final prefsAsync = ref.watch(customerNotificationPreferencesProvider);
    final prefs = prefsAsync.valueOrNull;
    final notifier = ref.read(customerNotificationPreferencesProvider.notifier);

    bool readPref(bool Function(dynamic) selector, bool fallback) {
      if (prefs == null) return fallback;
      return selector(prefs);
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildToggleTile(
            context, isDark,
            icon: Icons.notifications_active_rounded,
            iconColor: AppColors.primary,
            title: 'Push Notifications',
            subtitle: 'Receive push alerts on your device',
            value: readPref((p) => p.pushEnabled, true),
            onChanged: (val) => notifier.toggle('pushEnabled', val),
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.email_rounded,
            iconColor: AppColors.info,
            title: 'Email Notifications',
            subtitle: 'Get updates via email',
            value: readPref((p) => p.emailEnabled, true),
            onChanged: (val) => notifier.toggle('emailEnabled', val),
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.schedule_rounded,
            iconColor: AppColors.accent,
            title: 'EMI Reminder (1 day before)',
            subtitle: 'Get reminded 1 day before EMI due',
            value: readPref((p) => p.emiReminder1Day, true),
            onChanged: (val) => notifier.toggle('emiReminder1Day', val),
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.event_rounded,
            iconColor: AppColors.orange,
            title: 'EMI Reminder (3 days before)',
            subtitle: 'Get reminded 3 days before EMI due',
            value: readPref((p) => p.emiReminder3Days, true),
            onChanged: (val) => notifier.toggle('emiReminder3Days', val),
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.event_available_rounded,
            iconColor: AppColors.info,
            title: 'EMI Reminder (on due date)',
            subtitle: 'Get reminded on the EMI due date',
            value: readPref((p) => p.emiReminderOnDue, true),
            onChanged: (val) => notifier.toggle('emiReminderOnDue', val),
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.success,
            title: 'Payment Confirmation',
            subtitle: 'Confirm when payment is recorded',
            value: readPref((p) => p.paymentConfirmation, true),
            onChanged: (val) => notifier.toggle('paymentConfirmation', val),
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.emoji_events_rounded,
            iconColor: AppColors.warning,
            title: 'Savings Milestones',
            subtitle: 'Celebrate when you reach savings goals',
            value: readPref((p) => p.savingsMilestone, true),
            onChanged: (val) => notifier.toggle('savingsMilestone', val),
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.campaign_rounded,
            iconColor: AppColors.info,
            title: 'System Alerts',
            subtitle: 'Maintenance and announcements',
            value: readPref((p) => p.systemAlerts, true),
            onChanged: (val) => notifier.toggle('systemAlerts', val),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context, bool isDark) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildNavigationTile(
            context, isDark,
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.primary,
            title: 'App Version',
            trailing: Text(
              '1.0.0',
              style: TextStyle(
                color: (isDark ? Colors.white : const Color(0xFF0F172A))
                    .withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: null,
          ),
          _buildDivider(isDark),
          _buildNavigationTile(
            context, isDark,
            icon: Icons.description_rounded,
            iconColor: AppColors.info,
            title: 'Terms of Service',
            // TODO: open real terms URL once published.
            onTap: null,
          ),
          _buildDivider(isDark),
          _buildNavigationTile(
            context, isDark,
            icon: Icons.privacy_tip_rounded,
            iconColor: AppColors.teal,
            title: 'Privacy Policy',
            // TODO: open real privacy URL once published.
            onTap: null,
          ),
          _buildDivider(isDark),
          _buildNavigationTile(
            context, isDark,
            icon: Icons.star_rounded,
            iconColor: AppColors.warning,
            title: 'Rate This App',
            subtitle: 'Help us improve',
            // TODO: deep-link to Play Store / App Store once listing is live.
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: (isDark ? Colors.white : const Color(0xFF0F172A))
                          .withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 48,
            height: 28,
            child: FittedBox(
              fit: BoxFit.fill,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                inactiveThumbColor:
                    isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                inactiveTrackColor: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final hasChevron = onTap != null && trailing == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color:
                              (isDark ? Colors.white : const Color(0xFF0F172A))
                                  .withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (hasChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.3),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ChangePasswordSheet(isDark: isDark);
      },
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  final bool isDark;
  const _ChangePasswordSheet({required this.isDark});

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            kBottomNavBarHeight +
            16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2030) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Change Password',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          _buildPasswordField(
              _currentPwController, 'Current Password', isDark),
          const SizedBox(height: 12),
          _buildPasswordField(_newPwController, 'New Password', isDark),
          const SizedBox(height: 12),
          _buildPasswordField(
              _confirmPwController, 'Confirm New Password', isDark),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : _handleUpdate,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Update Password',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdate() async {
    if (_newPwController.text != _confirmPwController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).changePassword(
            currentPassword: _currentPwController.text,
            newPassword: _newPwController.text,
          );
      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Widget _buildPasswordField(
      TextEditingController controller, String hint, bool isDark) {
    return TextField(
      controller: controller,
      obscureText: true,
      enabled: !_isLoading,
      style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: (isDark ? Colors.white : const Color(0xFF0F172A))
              .withValues(alpha: 0.3),
        ),
        filled: true,
        fillColor: (isDark ? Colors.white : Colors.black)
            .withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
