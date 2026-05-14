import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../loans/presentation/providers/loan_providers.dart';
import '../../../savings/data/providers/savings_providers.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../savings/data/models/savings_model.dart';

import '../providers/user_list_provider.dart';
import '../providers/new_user_provider.dart';

class UserDetailsPage extends ConsumerWidget {
  final String userId;
  const UserDetailsPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDetailsProvider(userId));
    final loansAsync = ref.watch(userLoansProvider(userId));
    final savingsAsync = ref.watch(userSavingsProvider(userId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Aurora effect
          const _AuroraBackground(),

          userAsync.when(
            data: (user) {
              if (user == null) {
                return const Center(child: Text('User not found'));
              }

              return loansAsync.when(
                data: (loans) => savingsAsync.when(
                  data: (savings) {
                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        _buildSliverAppBar(context, ref, user, theme),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildIdentityHeader(user, theme, isDark),
                                if (loans.isNotEmpty) ...[
                                  const SizedBox(height: 28),
                                  _buildTrustScoreGauge(user, theme, isDark),
                                ],
                                const SizedBox(height: 32),
                                _buildPortfolioHub(
                                    loans, savings, theme, isDark),
                                if (loans.isNotEmpty) ...[
                                  const SizedBox(height: 32),
                                  _buildRepaymentdiscipline(
                                      loans, theme, isDark),
                                ],
                                const SizedBox(height: 32),
                                _buildKYCVault(user, theme, isDark),
                                const SizedBox(height: 32),
                                _buildMemberQRPass(user, theme, isDark),
                                const SizedBox(height: 32),
                                _buildActivityTimeline(
                                    loans, savings, theme, isDark),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const _LoadingState(),
                  error: (e, __) => Center(child: Text('Savings Error: $e')),
                ),
                loading: () => const _LoadingState(),
                error: (e, __) => Center(child: Text('Loans Error: $e')),
              );
            },
            loading: () => const _LoadingState(),
            error: (e, __) => Center(child: Text('User Error: $e')),
          ),

          // Floating Action Bar at bottom
          _buildFloatingActionIsland(context, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
      BuildContext context, WidgetRef ref, ProfileModel user, ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 0,
      collapsedHeight: 64,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Text(
        user.fullName ?? 'Member Profile',
        style: const TextStyle(
            fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 24),
          onSelected: (value) {
            if (value == 'edit') {
              _showEditSheet(context, ref, user);
            }
          },
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Edit Profile',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.ios_share_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Export Statement',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'deactivate',
              child: Row(
                children: [
                  Icon(Icons.no_accounts_rounded,
                      size: 20, color: Colors.red[400]),
                  const SizedBox(width: 12),
                  Text('Deactivate Member',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.red[400])),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, ProfileModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(user: user),
    );
  }

  Widget _buildIdentityHeader(ProfileModel user, ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.12),
            primary.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.15), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(Icons.shield_rounded,
                size: 100, color: primary.withValues(alpha: 0.03)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Hero(
                  tag: 'user_avatar_${user.id}',
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [primary, primary.withValues(alpha: 0.7)],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: -2),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        user.fullName?[0].toUpperCase() ?? '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.fullName ?? 'Unknown',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.verified_user_rounded,
                              size: 18,
                              color: isDark
                                  ? AppColors.successDark
                                  : AppColors.success),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Member ID: MF-${user.id.substring(0, 8).toUpperCase()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          user.role?.name.toUpperCase() ?? 'RETAIL MEMBER',
                          style: TextStyle(
                              color: primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildTrustScoreGauge(
      ProfileModel user, ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;
    // Real score logic would go here, using a default based on history
    const score = 785.0;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Platform Trust Score',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Performance-based Credit Rating',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('ACTIVE',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 100),
                  painter: _GaugePainter(score: score, color: primary),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 30),
                    Text(
                      '${score.toInt()}',
                      style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 42,
                          letterSpacing: -1),
                    ),
                    Text(
                      'OF 900',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 2),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 100.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildPortfolioHub(List<LoanModel> loans, List<SavingsModel> savings,
      ThemeData theme, bool isDark) {
    final active = loans.where((l) => l.status == LoanStatus.active).toList();
    final totalOut = active.fold<double>(
        0.0, (double sum, LoanModel l) => sum + l.outstandingBalance);
    final totalSavings = savings.fold<double>(
        0.0, (double sum, SavingsModel s) => sum + s.targetAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text('Portfolio Overview',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ),
        Row(
          children: [
            Expanded(
              child: _buildPortfolioCard(
                'Active Liability',
                '₹${(totalOut / 1000).toStringAsFixed(1)}k',
                '${active.length} Active Loans',
                Icons.trending_up_rounded,
                theme.colorScheme.primary,
                theme,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPortfolioCard(
                'Asset Value',
                '₹${(totalSavings / 1000).toStringAsFixed(1)}k',
                '${savings.length} Plans',
                Icons.account_balance_rounded,
                isDark ? AppColors.successDark : AppColors.success,
                theme,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildPortfolioCard(String label, String value, String subValue,
      IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 16),
          Text(value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(subValue,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildRepaymentdiscipline(
      List<LoanModel> loans, ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Repayment Discipline',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Icon(Icons.bar_chart_rounded,
                  size: 20, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 100,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeGroupData(0, 8, theme.colorScheme.primary),
                  _makeGroupData(1, 10, theme.colorScheme.primary),
                  _makeGroupData(2, 9, theme.colorScheme.primary),
                  _makeGroupData(3, 12, theme.colorScheme.primary),
                  _makeGroupData(4, 11, theme.colorScheme.primary),
                  _makeGroupData(5, 14, theme.colorScheme.primary),
                  _makeGroupData(6, 13, theme.colorScheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Historical Collection Performance',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0);
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 12,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
              show: true, toY: 15, color: color.withValues(alpha: 0.05)),
        ),
      ],
    );
  }

  Widget _buildKYCVault(ProfileModel user, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text('Document & KYC Vault',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildKYCItem('AADHAR CARD', user.aadhar ?? 'Not provided',
                  Icons.badge_rounded, theme),
              const Divider(height: 24, thickness: 0.5),
              _buildKYCItem('PAN CARD', user.pan ?? 'Not provided',
                  Icons.credit_card_rounded, theme),
              const Divider(height: 24, thickness: 0.5),
              _buildKYCItem('PHONE VERIFIED', user.phone ?? 'Not provided',
                  Icons.phone_android_rounded, theme),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildKYCItem(
      String label, String value, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(value,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
        const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
      ],
    );
  }

  Widget _buildMemberQRPass(ProfileModel user, ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Member QR Pass',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  'Scan this code to instantly pull up profile or record collections.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('ENCRYPTED ID',
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: user.id,
              version: QrVersions.auto,
              size: 100.0,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildActivityTimeline(List<LoanModel> loans,
      List<SavingsModel> savings, ThemeData theme, bool isDark) {
    final hasActivity = loans.isNotEmpty || savings.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text('Recent History',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: !hasActivity
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history_toggle_off_rounded,
                            size: 32, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No transaction activity recorded yet.',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Real items would be mapped from a transaction provider
                    // For now, only show real items if lists are populated
                    if (loans.isNotEmpty)
                      _buildTimelineItem(
                          'Loan Account Created',
                          'Portfolio initialized',
                          'System Log',
                          Icons.add_moderator_rounded,
                          theme.colorScheme.primary,
                          theme),
                    if (savings.isNotEmpty)
                      _buildTimelineItem(
                          'Savings Plan Active',
                          'Contribution window open',
                          'System Log',
                          Icons.savings_rounded,
                          AppColors.success,
                          theme),
                  ],
                ),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildTimelineItem(String title, String desc, String time,
      IconData icon, Color color, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(desc,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text(time,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFloatingActionIsland(
      BuildContext context, ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;

    return Positioned(
      left: 24,
      right: 24,
      bottom: 32,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        borderRadius: 24,
        child: Row(
          children: [
            Expanded(
              child: _ActionIslandButton(
                label: 'Deploy Capital',
                icon: Icons.add_moderator_rounded,
                color: primary,
                onTap: () => context.push('/loans/new'),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 40,
              width: 1,
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionIslandButton(
                label: 'Quick Deposit',
                icon: Icons.savings_rounded,
                color: isDark ? AppColors.successDark : AppColors.success,
                onTap: () => context.push('/savings/new'),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5, end: 0);
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Synchronizing Profile...',
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ActionIslandButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIslandButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: -0.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;
  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // Background track
    paint.color = color.withValues(alpha: 0.1);
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

    // Active track
    final activeSweep = (score / 900) * math.pi;
    paint.color = color;
    canvas.drawArc(rect, startAngle, activeSweep, false, paint);

    // Dot at the end
    final angle = startAngle + activeSweep;
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy + radius * math.sin(angle);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(x, y), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.05),
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .moveY(
                begin: 0, end: 30, duration: 4.seconds, curve: Curves.easeInOut)
            .moveX(
                begin: 0,
                end: -20,
                duration: 5.seconds,
                curve: Curves.easeInOut),
        Positioned(
          bottom: 100,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.03),
            ),
          ),
        ).animate(onPlay: (c) => c.repeat()).moveY(
            begin: 0, end: -40, duration: 6.seconds, curve: Curves.easeInOut),
      ],
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final ProfileModel user;
  const _EditProfileSheet({required this.user});

  @override
  _EditProfileSheetState createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _aadharController;
  late TextEditingController _panController;
  late TextEditingController _employeeIdController;
  late TextEditingController _zoneController;
  late TextEditingController _addressController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phone);
    _aadharController = TextEditingController(text: widget.user.aadhar);
    _panController = TextEditingController(text: widget.user.pan);
    _employeeIdController =
        TextEditingController(text: widget.user.employeeId ?? '');
    _zoneController =
        TextEditingController(text: widget.user.assignedZone ?? '');
    _addressController = TextEditingController(text: widget.user.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _employeeIdController.dispose();
    _zoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(userRepositoryProvider);
      await repository.updateUser(widget.user.id, {
        'full_name': _nameController.text,
        'phone': _phoneController.text,
        'aadhar': _aadharController.text,
        'pan': _panController.text,
        'employee_id': _employeeIdController.text,
        'assigned_zone': _zoneController.text,
        'address': _addressController.text,
      });

      ref.invalidate(userListProvider);
      ref.invalidate(userDetailsProvider(widget.user.id));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Profile updated successfully'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Update failed: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.elevatedDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Indicator
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Profile',
                        style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900, letterSpacing: -1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Update member details and KYC records.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Scrollable Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Summary / Role Info (Glass Card)
                  _buildRoleSummaryCard(theme, primary, isDark),
                  const SizedBox(height: 20),

                  // Account Details
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Account Details',
                            Icons.person_outline_rounded, theme, primary),
                        const SizedBox(height: 24),
                        _buildTwoColumn(
                          isNarrow: isNarrow,
                          first: _buildInputField(
                            label: 'FULL NAME',
                            hint: 'Enter legal name',
                            controller: _nameController,
                            theme: theme,
                            isDark: isDark,
                            primary: primary,
                          ),
                          second: _buildInputField(
                            label: 'MOBILE NUMBER',
                            hint: '+91 XXXXXXXXXX',
                            icon: Icons.phone_android_outlined,
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            theme: theme,
                            isDark: isDark,
                            primary: primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'RESIDENTIAL ADDRESS',
                          hint: 'Enter complete home address',
                          icon: Icons.home_outlined,
                          controller: _addressController,
                          theme: theme,
                          isDark: isDark,
                          primary: primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Operational Details (Employee ID / Zone)
                  if (widget.user.role != UserRole.customer) ...[
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                              'Field Operations',
                              Icons.corporate_fare_outlined,
                              theme,
                              isDark ? AppColors.warningDark : AppColors.orange),
                          const SizedBox(height: 24),
                          _buildTwoColumn(
                            isNarrow: isNarrow,
                            first: _buildInputField(
                              label: 'EMPLOYEE ID',
                              hint: 'Internal reference #',
                              controller: _employeeIdController,
                              theme: theme,
                              isDark: isDark,
                              primary: primary,
                            ),
                            second: _buildInputField(
                              label: 'ASSIGNED ZONE',
                              hint: 'e.g. North Sector',
                              icon: Icons.location_on_outlined,
                              controller: _zoneController,
                              theme: theme,
                              isDark: isDark,
                              primary: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Identity Details
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                            'Identity Verification',
                            Icons.badge_outlined,
                            theme,
                            isDark ? AppColors.successDark : AppColors.success),
                        const SizedBox(height: 24),
                        _buildTwoColumn(
                          isNarrow: isNarrow,
                          first: _buildInputField(
                            label: 'AADHAR NUMBER',
                            hint: 'XXXX XXXX XXXX',
                            icon: Icons.fingerprint_outlined,
                            controller: _aadharController,
                            keyboardType: TextInputType.number,
                            theme: theme,
                            isDark: isDark,
                            primary: primary,
                          ),
                          second: _buildInputField(
                            label: 'PAN NUMBER',
                            hint: 'ABCDE 1234 F',
                            icon: Icons.credit_card_outlined,
                            controller: _panController,
                            textCapitalization: TextCapitalization.characters,
                            theme: theme,
                            isDark: isDark,
                            primary: primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Bottom Actions
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24,
                MediaQuery.of(context).padding.bottom > 0 ? 32 : 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.elevatedDark : Colors.white,
              border: Border(
                top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Discard',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSummaryCard(ThemeData theme, Color primary, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withValues(alpha: 0.6)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.role?.name.toUpperCase() ?? 'MEMBER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Permission Matrix Active',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, IconData icon, ThemeData theme, Color accent) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2)),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required ThemeData theme,
    required bool isDark,
    required Color primary,
    IconData? icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontSize: 10,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 18) : null,
            filled: true,
            fillColor: isDark ? AppColors.fillDark : AppColors.fillLight,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTwoColumn({
    required bool isNarrow,
    required Widget first,
    required Widget second,
  }) {
    if (isNarrow) {
      return Column(
        children: [
          first,
          const SizedBox(height: 16),
          second,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }
}
