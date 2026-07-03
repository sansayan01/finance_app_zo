// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../providers/supabase_provider.dart';
import '../../data/providers/branch_scoped_providers.dart';

/// Premium branch-scoped member detail page.
/// Shows member info, active loans, savings, and recent transactions.
class BranchMemberDetailPage extends ConsumerWidget {
  final String memberId;

  const BranchMemberDetailPage({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final detailAsync = ref.watch(branchMemberDetailProvider(memberId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: detailAsync.when(
          data: (detail) => _buildContent(context, theme, isDark, detail, ref),
          loading: () => _buildLoading(theme, isDark),
          error: (error, _) => _buildError(context, theme, isDark, error, ref),
        ),
      ),
    );
  }

  Widget _buildLoading(ThemeData theme, bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: isDark
              ? const Color(0xFF0A0A0C).withValues(alpha: 0.85)
              : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Member Details',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          systemOverlayStyle:
              isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: 5,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ShimmerCard(height: 120),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Object error,
    WidgetRef ref,
  ) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: isDark
              ? const Color(0xFF0A0A0C).withValues(alpha: 0.85)
              : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Member Details',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          systemOverlayStyle:
              isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${error.toString()}'),
                const SizedBox(height: 16),
                GlassButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onTap: () => ref.invalidate(branchMemberDetailProvider(memberId)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> detail,
    WidgetRef ref,
  ) {
    final member = detail['member'] as Map<String, dynamic>?;
    final loansRaw = detail['loans'] as List<dynamic>? ?? [];
    final savingsRaw = detail['savings'] as List<dynamic>? ?? [];
    final transactionsRaw = detail['transactions'] as List<dynamic>? ?? [];

    if (member == null) {
      return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: isDark
                ? const Color(0xFF0A0A0C).withValues(alpha: 0.85)
                : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
            surfaceTintColor: Colors.transparent,
            title: const Text('Member Details'),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Member not found')),
          ),
        ],
      );
    }

    final name = member['full_name']?.toString() ?? 'Unknown';
    final phone = member['phone']?.toString() ?? '';
    final email = member['email']?.toString() ?? '';
    final address = member['address']?.toString() ?? '';
    final status = member['status']?.toString() ?? 'active';
    final kycStatus = member['kyc_status']?.toString() ?? 'pending';
    final isActive = status == 'active';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(branchMemberDetailProvider(memberId));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // App Bar
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: isDark
                ? const Color(0xFF0A0A0C).withValues(alpha: 0.85)
                : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Member Details',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            systemOverlayStyle:
                isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          ),

          // Profile Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildProfileHeader(theme, isDark, name, phone, email,
                  address, status, kycStatus, isActive),
            ),
          ),

          // Contact Actions
          if (phone.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _buildContactActions(theme, isDark, phone),
              ),
            ),

          // SMS Notification Toggle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildSmsToggle(context, ref, theme, isDark, memberId, member),
            ),
          ),

          // Active Loans Section
          if (loansRaw.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _buildSectionHeader(theme, isDark, 'Loans', '${loansRaw.length}'),
              ),
            ),
          if (loansRaw.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: loansRaw.length,
                itemBuilder: (context, index) {
                  final loan = loansRaw[index] as Map<String, dynamic>;
                  return _buildLoanCard(theme, isDark, loan, index);
                },
              ),
            ),
          if (loansRaw.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Savings Section
          if (savingsRaw.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _buildSectionHeader(theme, isDark, 'Savings', '${savingsRaw.length}'),
              ),
            ),
          if (savingsRaw.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: savingsRaw.length,
                itemBuilder: (context, index) {
                  final saving = savingsRaw[index] as Map<String, dynamic>;
                  return _buildSavingsCard(theme, isDark, saving, index);
                },
              ),
            ),
          if (savingsRaw.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Recent Transactions
          if (transactionsRaw.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _buildSectionHeader(theme, isDark, 'Recent Transactions', '${transactionsRaw.length}'),
              ),
            ),
          if (transactionsRaw.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: transactionsRaw.length.clamp(0, 10),
                itemBuilder: (context, index) {
                  final txn = transactionsRaw[index] as Map<String, dynamic>;
                  return _buildTransactionCard(theme, isDark, txn, index);
                },
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // Profile Header
  Widget _buildProfileHeader(
    ThemeData theme,
    bool isDark,
    String name,
    String phone,
    String email,
    String address,
    String status,
    String kycStatus,
    bool isActive,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [AppColors.primary.withValues(alpha: 0.8), AppColors.accent.withValues(alpha: 0.6)]
                        : [Colors.grey.withValues(alpha: 0.5), Colors.grey.withValues(alpha: 0.3)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
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
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        StatusBadge(
                          label: isActive ? 'Active' : 'Inactive',
                          type: isActive ? StatusType.active : StatusType.defaultStatus,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kycStatus == 'verified'
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'KYC: ${kycStatus[0].toUpperCase()}${kycStatus.substring(1)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: kycStatus == 'verified'
                                  ? AppColors.success
                                  : AppColors.warning,
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
          if (phone.isNotEmpty || email.isNotEmpty || address.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
            const SizedBox(height: 12),
            if (phone.isNotEmpty)
              _buildInfoRow(Icons.phone_rounded, phone, isDark),
            if (email.isNotEmpty)
              _buildInfoRow(Icons.email_rounded, email, isDark),
            if (address.isNotEmpty)
              _buildInfoRow(Icons.location_on_rounded, address, isDark),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildInfoRow(IconData icon, String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Contact Actions
  Widget _buildContactActions(ThemeData theme, bool isDark, String phone) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 14),
            onTap: () => launchUrl(Uri.parse('tel:$phone')),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call_rounded, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Call',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 14),
            onTap: () => launchUrl(Uri.parse('sms:$phone')),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.message_rounded, color: AppColors.info, size: 18),
                const SizedBox(width: 8),
                Text(
                  'SMS',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildSmsToggle(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool isDark,
    String memberId,
    Map<String, dynamic>? member,
  ) {
    final smsEnabled = member?['sms_enabled'] as bool? ?? true;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (smsEnabled ? AppColors.success : Colors.grey).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              smsEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              color: smsEnabled ? AppColors.success : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMS Notifications',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  smsEnabled ? 'Enabled — customer receives SMS alerts' : 'Disabled — no SMS sent',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: smsEnabled,
            activeColor: AppColors.success,
            onChanged: (value) async {
              try {
                final client = ref.read(supabaseClientProvider);
                await client
                    .from('members')
                    .update({'sms_enabled': value})
                    .eq('id', memberId);
                ref.invalidate(branchMemberDetailProvider(memberId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value ? 'SMS notifications enabled' : 'SMS notifications disabled'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }

  // Section Header
  Widget _buildSectionHeader(ThemeData theme, bool isDark, String title, String count) {
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 150.ms);
  }

  // Loan Card
  Widget _buildLoanCard(ThemeData theme, bool isDark, Map<String, dynamic> loan, int index) {
    final amount = (loan['amount'] as num?)?.toDouble() ?? 0;
    final outstanding = (loan['outstanding_amount'] as num?)?.toDouble() ?? 0;
    final status = loan['status']?.toString() ?? 'active';
    final loanNumber = loan['loan_number']?.toString() ?? '';
    final progress = amount > 0 ? (1 - (outstanding / amount)).clamp(0.0, 1.0) : 0.0;

    StatusType statusType;
    String statusLabel;
    switch (status) {
      case 'active':
        statusType = StatusType.active;
        statusLabel = 'Active';
        break;
      case 'default':
      case 'defaulted':
        statusType = StatusType.defaultStatus;
        statusLabel = 'At Risk';
        break;
      case 'closed':
        statusType = StatusType.completed;
        statusLabel = 'Closed';
        break;
      default:
        statusType = StatusType.standard;
        statusLabel = status;
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loanNumber.isNotEmpty ? loanNumber : 'Loan',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              StatusBadge(label: statusLabel, type: statusType),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniStat(theme, isDark, 'Amount', AppFormatters.formatCurrency(amount)),
              const SizedBox(width: 20),
              _buildMiniStat(
                theme, isDark, 'Outstanding', AppFormatters.formatCurrency(outstanding),
                valueColor: outstanding > 0 ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor:
                  isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(
                progress >= 1 ? AppColors.success : AppColors.info,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, delay: Duration(milliseconds: 60 * index.clamp(0, 5)));
  }

  // Savings Card
  Widget _buildSavingsCard(ThemeData theme, bool isDark, Map<String, dynamic> saving, int index) {
    final planName = saving['plan_name']?.toString() ?? 'Savings';
    final currentAmount = (saving['current_amount'] as num?)?.toDouble() ?? 0;
    final targetAmount = (saving['target_amount'] as num?)?.toDouble() ?? 0;
    final status = saving['status']?.toString() ?? 'active';
    final progress = targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

    StatusType statusType;
    String statusLabel;
    switch (status) {
      case 'active':
        statusType = StatusType.active;
        statusLabel = 'Active';
        break;
      case 'matured':
        statusType = StatusType.completed;
        statusLabel = 'Matured';
        break;
      default:
        statusType = StatusType.standard;
        statusLabel = status;
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planName,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              StatusBadge(label: statusLabel, type: statusType),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniStat(theme, isDark, 'Saved', AppFormatters.formatCurrency(currentAmount),
                  valueColor: AppColors.success),
              const SizedBox(width: 20),
              _buildMiniStat(theme, isDark, 'Target', AppFormatters.formatCurrency(targetAmount)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor:
                  isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(
                progress >= 1 ? AppColors.success : AppColors.teal,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, delay: Duration(milliseconds: 60 * index.clamp(0, 5)));
  }

  Widget _buildMiniStat(
    ThemeData theme,
    bool isDark,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // Transaction Card
  Widget _buildTransactionCard(ThemeData theme, bool isDark, Map<String, dynamic> txn, int index) {
    final amount = (txn['amount'] as num?)?.toDouble() ?? 0;
    final type = txn['type']?.toString() ?? 'collection';
    final txnDate = txn['created_at']?.toString();
    final paymentMode = txn['payment_mode']?.toString() ?? '';

    final dateStr = txnDate != null
        ? AppFormatters.formatDate(DateTime.tryParse(txnDate) ?? DateTime.now())
        : '';

    final isCredit = type == 'collection' || type == 'deposit' || type == 'credit';
    final icon = isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final color = isCredit ? AppColors.success : AppColors.warning;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type[0].toUpperCase() + type.substring(1),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  [if (paymentMode.isNotEmpty) paymentMode, if (dateStr.isNotEmpty) dateStr]
                      .join(' - '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${AppFormatters.formatCurrency(amount)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: 40 * index.clamp(0, 8)));
  }
}
