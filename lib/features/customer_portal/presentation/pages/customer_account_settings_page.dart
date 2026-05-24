import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/customer_biometric_providers.dart';

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

  // Notification preferences
  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _emiReminder1Day = true;
  bool _emiReminder3Days = true;
  bool _paymentConfirmation = true;
  bool _savingsMilestone = true;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pushEnabled = prefs.getBool('notif_push') ?? true;
      _emailEnabled = prefs.getBool('notif_email') ?? true;
      _emiReminder1Day = prefs.getBool('notif_emi_1day') ?? true;
      _emiReminder3Days = prefs.getBool('notif_emi_3days') ?? true;
      _paymentConfirmation = prefs.getBool('notif_payment') ?? true;
      _savingsMilestone = prefs.getBool('notif_savings') ?? true;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Animation<double> _staggered(int index) {
    final start = (index * 0.08).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);
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
          offset: Offset(0, 20 * (1 - _staggered(index).value)),
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

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Gradient header
          SliverToBoxAdapter(
            child: _buildHeader(context, isDark, user),
          ),

          // Profile summary
          SliverToBoxAdapter(
            child: _animatedEntry(
              0,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _buildProfileSummary(context, isDark, user),
              ),
            ),
          ),

          // Security section
          SliverToBoxAdapter(
            child: _animatedEntry(
              1,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _buildSectionHeader(context, 'Security', Icons.shield_rounded, isDark),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _animatedEntry(
              2,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _buildSecuritySection(context, isDark),
              ),
            ),
          ),

          // Notifications section
          SliverToBoxAdapter(
            child: _animatedEntry(
              3,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _buildSectionHeader(context, 'Notifications', Icons.notifications_rounded, isDark),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _animatedEntry(
              4,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _buildNotificationsSection(context, isDark),
              ),
            ),
          ),

          // About section
          SliverToBoxAdapter(
            child: _animatedEntry(
              5,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _buildSectionHeader(context, 'About', Icons.info_rounded, isDark),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _animatedEntry(
              6,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _buildAboutSection(context, isDark),
              ),
            ),
          ),

          // Danger zone
          SliverToBoxAdapter(
            child: _animatedEntry(
              7,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _buildDangerZone(context, isDark),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, dynamic user) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1F3A), const Color(0xFF151A30)]
              : [AppColors.primary, AppColors.accent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 24),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              const Expanded(
                child: Text(
                  'Account Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSummary(BuildContext context, bool isDark, dynamic user) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
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
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'User',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    color: (isDark ? Colors.white : const Color(0xFF0F172A))
                        .withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Customer',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w700,
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
              return _buildToggleTile(
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
              );
            },
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
                height: 1,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.06)),
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
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Soon',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context, bool isDark) {
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
            value: _pushEnabled,
            onChanged: (val) {
              setState(() => _pushEnabled = val);
              _savePref('notif_push', val);
            },
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.email_rounded,
            iconColor: AppColors.info,
            title: 'Email Notifications',
            subtitle: 'Get updates via email',
            value: _emailEnabled,
            onChanged: (val) {
              setState(() => _emailEnabled = val);
              _savePref('notif_email', val);
            },
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.schedule_rounded,
            iconColor: AppColors.accent,
            title: 'EMI Reminder (1 day before)',
            subtitle: 'Get reminded 1 day before EMI due',
            value: _emiReminder1Day,
            onChanged: (val) {
              setState(() => _emiReminder1Day = val);
              _savePref('notif_emi_1day', val);
            },
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.event_rounded,
            iconColor: AppColors.orange,
            title: 'EMI Reminder (3 days before)',
            subtitle: 'Get reminded 3 days before EMI due',
            value: _emiReminder3Days,
            onChanged: (val) {
              setState(() => _emiReminder3Days = val);
              _savePref('notif_emi_3days', val);
            },
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.success,
            title: 'Payment Confirmation',
            subtitle: 'Confirm when payment is recorded',
            value: _paymentConfirmation,
            onChanged: (val) {
              setState(() => _paymentConfirmation = val);
              _savePref('notif_payment', val);
            },
          ),
          _buildDivider(isDark),
          _buildToggleTile(
            context, isDark,
            icon: Icons.emoji_events_rounded,
            iconColor: AppColors.warning,
            title: 'Savings Milestones',
            subtitle: 'Celebrate when you reach savings goals',
            value: _savingsMilestone,
            onChanged: (val) {
              setState(() => _savingsMilestone = val);
              _savePref('notif_savings', val);
            },
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
                    .withValues(alpha: 0.4),
                fontSize: 13,
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
            onTap: () {},
          ),
          _buildDivider(isDark),
          _buildNavigationTile(
            context, isDark,
            icon: Icons.privacy_tip_rounded,
            iconColor: AppColors.teal,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          _buildDivider(isDark),
          _buildNavigationTile(
            context, isDark,
            icon: Icons.star_rounded,
            iconColor: AppColors.warning,
            title: 'Rate This App',
            subtitle: 'Help us improve',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Permanently delete your account and all associated data. This action cannot be undone.',
            style: TextStyle(
              color: (isDark ? Colors.white : const Color(0xFF0F172A))
                  .withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDeleteAccountDialog(context, isDark),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Delete Account'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: (isDark ? Colors.white : const Color(0xFF0F172A))
                          .withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color:
                              (isDark ? Colors.white : const Color(0xFF0F172A))
                                  .withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
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
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: EdgeInsets.fromLTRB(
                  24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
                      currentPwController, 'Current Password', isDark),
                  const SizedBox(height: 12),
                  _buildPasswordField(
                      newPwController, 'New Password', isDark),
                  const SizedBox(height: 12),
                  _buildPasswordField(
                      confirmPwController, 'Confirm New Password', isDark),
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
                          onTap: isLoading
                              ? null
                              : () async {
                                  if (newPwController.text !=
                                      confirmPwController.text) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Passwords do not match')),
                                    );
                                    return;
                                  }
                                  final messenger = ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(ctx);
                                  setSheetState(() => isLoading = true);
                                  try {
                                    await ref
                                        .read(authProvider.notifier)
                                        .changePassword(
                                          currentPassword:
                                              currentPwController.text,
                                          newPassword: newPwController.text,
                                        );
                                    if (ctx.mounted) navigator.pop();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Password changed successfully')),
                                    );
                                  } catch (e) {
                                    setSheetState(() => isLoading = false);
                                    messenger.showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Error: ${e.toString()}')),
                                    );
                                  }
                                },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
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
          },
        );
      },
    );
  }

  Widget _buildPasswordField(
      TextEditingController controller, String hint, bool isDark) {
    return TextField(
      controller: controller,
      obscureText: true,
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

  void _showDeleteAccountDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C2030) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error),
            const SizedBox(width: 10),
            const Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'This will permanently delete your account, all loans, savings, and transaction history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Please contact support to delete your account')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
