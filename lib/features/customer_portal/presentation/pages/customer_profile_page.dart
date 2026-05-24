import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/customer_profile_model.dart';
import '../../data/providers/customer_profile_providers.dart';
import '../../data/providers/customer_member_provider.dart';

class CustomerProfilePage extends ConsumerStatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  ConsumerState<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends ConsumerState<CustomerProfilePage>
    with TickerProviderStateMixin {
  late AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  Animation<double> _anim(int i) {
    final s = (i * 0.08).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _stagger,
      curve: Interval(s, (s + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
  }

  Widget _fadeSlide(int i, Widget child) {
    return AnimatedBuilder(
      animation: _anim(i),
      builder: (context, child) => Opacity(
        opacity: _anim(i).value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - _anim(i).value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(customerProfileProvider);
    final memberIdAsync = ref.watch(currentCustomerIdProvider);

    return Scaffold(
      body: memberIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (memberId) {
          if (memberId == null) {
            return const Center(child: Text('Account not linked'));
          }
          return profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (profile) {
              if (profile == null) {
                return const Center(child: Text('Profile not found'));
              }
              return _buildBody(context, profile);
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, CustomerProfileModel profile) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(customerProfileProvider),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context, profile, isDark)),
          SliverToBoxAdapter(child: _fadeSlide(0, _buildAvatarSection(context, profile, isDark))),
          SliverToBoxAdapter(child: _fadeSlide(1, _buildSection(context, 'Personal Info', Icons.person_rounded, isDark, [
            _infoRow(context, 'Full Name', profile.fullName, isDark, editable: true, onEdit: () => _editField(context, 'full_name', 'Full Name', profile.fullName, profile)),
            _infoRow(context, 'Phone', profile.phone, isDark, editable: true, onEdit: () => _editField(context, 'phone', 'Phone', profile.phone, profile)),
            _infoRow(context, 'Email', profile.email ?? '--', isDark),
            _infoRow(context, 'Date of Birth', profile.formattedDob, isDark, editable: true, onEdit: () => _pickDate(context, profile)),
            _infoRow(context, 'Gender', profile.gender ?? '--', isDark, editable: true, onEdit: () => _editDropdown(context, 'gender', 'Gender', ['Male', 'Female', 'Other'], profile.gender, profile)),
          ]))),
          SliverToBoxAdapter(child: _fadeSlide(2, _buildSection(context, 'Address', Icons.location_on_rounded, isDark, [
            _infoRow(context, 'Area', profile.area ?? '--', isDark, editable: true, onEdit: () => _editField(context, 'area', 'Area', profile.area ?? '', profile)),
            _infoRow(context, 'Village/City', profile.village ?? '--', isDark, editable: true, onEdit: () => _editField(context, 'village', 'Village/City', profile.village ?? '', profile)),
            _infoRow(context, 'Address', profile.address ?? '--', isDark, editable: true, onEdit: () => _editField(context, 'address', 'Address', profile.address ?? '', profile)),
          ]))),
          SliverToBoxAdapter(child: _fadeSlide(3, _buildSection(context, 'Identity', Icons.badge_rounded, isDark, [
            _infoRow(context, 'Aadhar Number', profile.maskedAadhar, isDark),
            _infoRow(context, 'PAN Number', profile.maskedPan, isDark),
          ]))),
          SliverToBoxAdapter(child: _fadeSlide(4, _buildSection(context, 'Financial', Icons.account_balance_rounded, isDark, [
            _infoRow(context, 'Occupation', profile.occupation ?? '--', isDark, editable: true, onEdit: () => _editField(context, 'occupation', 'Occupation', profile.occupation ?? '', profile)),
            _infoRow(context, 'Monthly Income', profile.formattedMonthlyIncome, isDark, editable: true, onEdit: () => _editField(context, 'monthly_income', 'Monthly Income', profile.monthlyIncome?.toStringAsFixed(0) ?? '', profile, isNumeric: true)),
          ]))),
          SliverToBoxAdapter(child: _fadeSlide(5, _buildSection(context, 'Account Info', Icons.info_rounded, isDark, [
            _infoRow(context, 'Member Since', profile.formattedJoinedDate, isDark),
            _infoRow(context, 'Total Loans', '${profile.totalLoans}', isDark),
            _infoRow(context, 'Total Savings', _formatCurrency(profile.totalSavings), isDark),
          ]))),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CustomerProfileModel profile, bool isDark) {
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              const Expanded(
                child: Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(BuildContext context, CustomerProfileModel profile, bool isDark) {
    final kycColor = profile.kycStatus == 'verified'
        ? AppColors.success
        : profile.kycStatus == 'rejected'
            ? AppColors.error
            : AppColors.warning;
    final kycLabel = profile.kycStatus[0].toUpperCase() + profile.kycStatus.substring(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Center(
                child: Text(profile.initials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            Text(profile.fullName, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(profile.phone, style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF0F172A)).withValues(alpha: 0.5), fontSize: 14)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: kycColor.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kycColor.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(profile.kycStatus == 'verified' ? Icons.verified_rounded : Icons.shield_rounded, color: kycColor, size: 16),
                const SizedBox(width: 6),
                Text(kycLabel, style: TextStyle(color: kycColor, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon, bool isDark, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: AppColors.primary, size: 16)),
                const SizedBox(width: 10),
                Text(title, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value, bool isDark, {bool editable = false, VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF0F172A)).withValues(alpha: 0.4), fontSize: 12)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
        ),
        if (editable && onEdit != null)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.edit_rounded, color: AppColors.primary, size: 14),
            ),
          ),
      ]),
    );
  }

  void _editField(BuildContext context, String field, String label, String current, CustomerProfileModel profile, {bool isNumeric = false}) {
    final controller = TextEditingController(text: current);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2030) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Edit $label', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: label,
                hintStyle: TextStyle(color: (isDark ? Colors.white : const Color(0xFF0F172A)).withValues(alpha: 0.3)),
                filled: true,
                fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]), borderRadius: BorderRadius.circular(16)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final value = controller.text.trim();
                      if (value.isEmpty) return;
                      final data = <String, dynamic>{};
                      if (field == 'monthly_income') {
                        data[field] = double.tryParse(value) ?? 0;
                      } else if (field == 'date_of_birth') {
                        // handled separately
                      } else {
                        data[field] = value;
                      }
                      await ref.read(customerProfileUpdateProvider.notifier).updateProfile(profile.memberId, data);
                      if (ctx.mounted) Navigator.pop(ctx);
                      ref.invalidate(customerProfileProvider);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('Save', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  void _editDropdown(BuildContext context, String field, String label, List<String> options, String? current, CustomerProfileModel profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2030) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Select $label', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await ref.read(customerProfileUpdateProvider.notifier).updateProfile(profile.memberId, {field: opt});
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(customerProfileProvider);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: current == opt ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1) : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: current == opt ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
                    ),
                    child: Row(children: [
                      Expanded(child: Text(opt, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w500))),
                      if (current == opt) Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
                    ]),
                  ),
                ),
              ),
            )),
          ]),
        );
      },
    );
  }

  void _pickDate(BuildContext context, CustomerProfileModel profile) async {
    final date = await showDatePicker(
      context: context,
      initialDate: profile.dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    if (date != null) {
      await ref.read(customerProfileUpdateProvider.notifier).updateProfile(profile.memberId, {'date_of_birth': date.toIso8601String().split('T').first});
      ref.invalidate(customerProfileProvider);
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) return '\u20b9${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '\u20b9${(amount / 1000).toStringAsFixed(1)}K';
    return '\u20b9${amount.toStringAsFixed(0)}';
  }
}
