// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';



import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/powered_by_badge.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../chatbot/presentation/providers/chat_config_provider.dart';
import '../../data/providers/branch_manager_providers.dart';
import '../../data/providers/branch_scoped_providers.dart';

class BranchSettingsPage extends ConsumerWidget {
  const BranchSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final branchId = user?.branchId;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ─── App Bar ───
            SliverAppBar(
              expandedHeight: 140.0,
              collapsedHeight: 70.0,
              floating: false,
              pinned: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                centerTitle: false,
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'Branch Manager',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Menu List ───
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ─── SECTION 1: ACCOUNT & PREFERENCES ──────────────
                  _buildSectionHeader(theme, 'ACCOUNT & PREFERENCES'),
                  _buildMenuCard(
                    theme: theme,
                    icon: Icons.person_outline_rounded,
                    title: 'Profile Settings',
                    subtitle: 'Name, phone, email, and security',
                    color: AppColors.primary,
                    onTap: () => context.push('/branch/profile'),
                  ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 12),

                  _buildQuickSettingsCard(theme, ref)
                      .animate()
                      .fadeIn(delay: 80.ms)
                      .slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 28),

                  // ─── SECTION 2: BRANCH OPERATIONS ───────────────────
                  _buildSectionHeader(theme, 'BRANCH OPERATIONS'),
                  if (branchId != null) ...[
                    _buildBranchInfoCard(theme, ref, branchId)
                        .animate()
                        .fadeIn(delay: 110.ms)
                        .slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 12),
                    _buildBranchTargetsCard(theme, ref, branchId, context)
                        .animate()
                        .fadeIn(delay: 140.ms)
                        .slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 12),
                  ],
                  _buildMenuCard(
                    theme: theme,
                    icon: Icons.people_outline_rounded,
                    title: 'Staff Overview',
                    subtitle: 'View branch staff and their performance',
                    color: Colors.teal,
                    onTap: () => context.push('/branch/members'),
                  ).animate().fadeIn(delay: 170.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 28),

                  // ─── SECTION 3: SECURITY ────────────────────────────
                  _buildSectionHeader(theme, 'SECURITY & COMPLIANCE'),
                  _buildMenuCard(
                    theme: theme,
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    color: Colors.orange,
                    onTap: () => _showChangePasswordDialog(context, ref),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    theme: theme,
                    icon: Icons.security_rounded,
                    title: 'Security & Activity',
                    subtitle: 'Session info and recent activity',
                    color: Colors.deepOrange,
                    onTap: () => _showSessionInfo(context, ref),
                  ).animate().fadeIn(delay: 230.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 28),

                  // ─── SECTION 4: SUPPORT ─────────────────────────────
                  _buildSectionHeader(theme, 'SUPPORT & ABOUT'),
                  _buildMenuCard(
                    theme: theme,
                    icon: Icons.support_agent_rounded,
                    title: 'Help & Support',
                    subtitle: 'FAQs, report issues, and policies',
                    color: Colors.blueGrey,
                    onTap: () => _showSupportSheet(context),
                  ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    theme: theme,
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    subtitle: 'End your session on this device',
                    color: Colors.redAccent,
                    onTap: () => _confirmSignOut(context, ref),
                  ).animate().fadeIn(delay: 290.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 48),

                  // ─── Footer ───
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'MicroFlow Pro — Branch Edition',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'v1.0.8-production',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const PoweredByBadge(compact: true),
                      ],
                    ),
                  ).animate().fadeIn(delay: 320.ms),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section Header ────────────────────────────────────────────────
  Widget _buildSectionHeader(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  // ─── Menu Card ─────────────────────────────────────────────────────
  Widget _buildMenuCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.6),
                        )),
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right_rounded,
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.3),
                      size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Quick Settings Card ───────────────────────────────────────────
  Widget _buildQuickSettingsCard(ThemeData theme, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Quick Preferences',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          _buildToggleRow(
            theme: theme,
            label: 'Dark Mode',
            description: 'Switch between light and dark theme',
            value: isDark,
            onChanged: (_) =>
                ref.read(themeProvider.notifier).toggleTheme(),
          ),
          const SizedBox(height: 8),
          _buildToggleRow(
            theme: theme,
            label: 'Push Notifications',
            description: 'Alerts for overdue EMIs and new members',
            value: settings.enableNotifications,
            onChanged: notifier.toggleNotifications,
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final chatConfig = ref.watch(chatConfigProvider);
              return _buildToggleRow(
                theme: theme,
                label: 'AI Assistant',
                description: chatConfig.chatbotEnabled
                    ? 'Floating chatbot is active'
                    : 'Chatbot is hidden',
                value: chatConfig.chatbotEnabled,
                onChanged: (_) =>
                    ref.read(chatConfigProvider.notifier).toggleChatbot(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required ThemeData theme,
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            Text(description,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.primary,
        ),
      ],
    );
  }

  // ─── Branch Info Card ──────────────────────────────────────────────
  Widget _buildBranchInfoCard(
      ThemeData theme, WidgetRef ref, String branchId) {
    final branchAsync = ref.watch(branchInfoProvider(branchId));
    final staffAsync = ref.watch(branchStaffProvider(branchId));

    return branchAsync.when(
      data: (branch) {
        if (branch == null) {
          return const SizedBox.shrink();
        }
        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.business_rounded,
                      size: 18, color: Colors.indigo),
                  const SizedBox(width: 10),
                  Text('Branch Information',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              _infoRow(theme, 'Branch Name',
                  branch['name']?.toString() ?? 'N/A'),
              _infoRow(theme, 'Branch Code',
                  branch['code']?.toString() ?? 'N/A'),
              _infoRow(theme, 'Address',
                  branch['address']?.toString() ?? 'N/A'),
              _infoRow(theme, 'Phone',
                  branch['phone']?.toString() ?? 'N/A'),
              _infoRow(theme, 'Email',
                  branch['email']?.toString() ?? 'N/A'),
              _infoRow(
                theme,
                'Status',
                (branch['status']?.toString() ?? 'active').toUpperCase(),
                valueColor: branch['status'] == 'active'
                    ? AppColors.success
                    : Colors.orange,
              ),
              const Divider(height: 24),
              staffAsync.when(
                data: (staff) => _infoRow(
                    theme, 'Total Staff', '${staff.length}'),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.6))),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor)),
          ),
        ],
      ),
    );
  }

  // ─── Branch Targets Card ───────────────────────────────────────────
  Widget _buildBranchTargetsCard(
      ThemeData theme, WidgetRef ref, String branchId, BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded,
                  size: 18, color: Colors.deepPurple),
              const SizedBox(width: 10),
              Text('Branch Targets',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showEditTargetsDialog(context, ref, branchId),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Edit',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Set monthly collection and member growth targets for your branch.',
            style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color
                    ?.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.construction_rounded,
                    size: 16, color: Colors.amber),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Targets are stored locally. Server-side sync coming soon.',
                    style: TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Change Password Dialog ────────────────────────────────────────
  void _showChangePasswordDialog(
      BuildContext context, WidgetRef ref) {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom +
                  24,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lock_outline_rounded,
                            color: Colors.orange, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Change Password',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          Text('Update your account password',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: currentPwController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20),
                        onPressed: () => setSheetState(
                            () => obscureCurrent = !obscureCurrent),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Enter current password'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPwController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20),
                        onPressed: () => setSheetState(
                            () => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter new password';
                      if (v.length < 8) return 'Minimum 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPwController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20),
                        onPressed: () => setSheetState(
                            () => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v != newPwController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() => isLoading = true);
                                  try {
                                    final success = await ref
                                        .read(authProvider.notifier)
                                        .changePassword(
                                          currentPassword: currentPwController.text,
                                          newPassword: newPwController.text,
                                        );
                                    if (!success) throw Exception('Current password is incorrect');
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text(
                                            'Password updated successfully'),
                                        backgroundColor: AppColors.success,
                                      ));
                                    }
                                  } catch (e) {
                                    setSheetState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(e.toString().replaceAll(
                                            'Exception: ', '')),
                                        backgroundColor: Colors.redAccent,
                                      ));
                                    }
                                  }
                                },
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                              isLoading ? 'Updating...' : 'Update Password'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Edit Targets Dialog ───────────────────────────────────────────
  void _showEditTargetsDialog(
      BuildContext context, WidgetRef ref, String branchId) {
    final collectionController =
        TextEditingController(text: '500000');
    final memberController = TextEditingController(text: '20');
    final disbursementController =
        TextEditingController(text: '1000000');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).padding.bottom +
              24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flag_rounded,
                      color: Colors.deepPurple, size: 22),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Branch Targets',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Set monthly goals for your branch',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: collectionController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Monthly Collection Target',
                prefixText: '\u20B9 ',
                prefixStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: disbursementController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Monthly Disbursement Target',
                prefixText: '\u20B9 ',
                prefixStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: memberController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'New Members Target',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Save to branch_targets table when migration is applied
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Targets saved locally'),
                    backgroundColor: AppColors.success,
                  ));
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Targets',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Session Info ──────────────────────────────────────────────────
  void _showSessionInfo(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.security_rounded,
                      color: Colors.deepOrange, size: 22),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Session Info',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Your current session details',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sessionRow('Name', user?.fullName ?? 'N/A'),
            _sessionRow('Email', user?.email ?? 'N/A'),
            _sessionRow('Role', user?.role?.name ?? 'N/A'),
            _sessionRow(
                'Branch', user?.branchId ?? 'Not assigned'),
            _sessionRow('User ID', user?.id ?? 'N/A'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 16, color: AppColors.success),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Session is active and secure.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Support Sheet ─────────────────────────────────────────────────
  void _showSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Help & Support',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.help_center_outlined,
                  color: AppColors.primary),
              title: const Text('Help Center & FAQs',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle:
                  const Text('Guides, tutorials, and troubleshooting'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Help Center coming soon')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined,
                  color: Colors.orange),
              title: const Text('Report an Issue',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Submit a bug report or feedback'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Issue reporting coming soon')));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.policy_outlined, color: Colors.teal),
              title: const Text('Privacy Policy & Terms',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Legal disclosures and compliance'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Policies page coming soon')));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sign Out ──────────────────────────────────────────────────────
  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content:
            const Text('Are you sure you want to end your session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).signOut();
            },
            child: const Text('Sign Out',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
