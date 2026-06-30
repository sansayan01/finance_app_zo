import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../payments/data/providers/upi_providers.dart';
import '../../../payments/data/services/upi_service.dart';

class IntegrationsSettingsPage extends ConsumerStatefulWidget {
  const IntegrationsSettingsPage({super.key});

  @override
  ConsumerState<IntegrationsSettingsPage> createState() => _IntegrationsSettingsPageState();
}

class _IntegrationsSettingsPageState extends ConsumerState<IntegrationsSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ─── UPI Config State ───
  final _upiVpaCtrl = TextEditingController();
  final _upiMerchantCtrl = TextEditingController();
  bool _savingUpi = false;
  bool _loadingUpiConfig = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUpiConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _upiVpaCtrl.dispose();
    _upiMerchantCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUpiConfig() async {
    try {
      final config = await ref.read(upiServiceProvider).getOrgVpa();
      if (!mounted) return;
      setState(() {
        _upiVpaCtrl.text = (config?['upi_vpa'] as String?) ?? '';
        _upiMerchantCtrl.text = (config?['merchant_name'] as String?) ?? '';
        _loadingUpiConfig = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUpiConfig = false);
    }
  }

  Future<void> _saveUpi() async {
    final vpa = _upiVpaCtrl.text.trim();
    final merchant = _upiMerchantCtrl.text.trim();

    if (vpa.isEmpty && merchant.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter VPA and merchant name to configure UPI.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (vpa.isNotEmpty && !UpiService.isValidVpa(vpa)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid VPA. It must contain an "@" symbol.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _savingUpi = true);
    try {
      await ref.read(upiServiceProvider).saveOrgVpa(
            vpa: vpa,
            merchantName: merchant,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('UPI payment configuration saved')),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save UPI config: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingUpi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Integrations & APIs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.forum_outlined, size: 20), text: 'Communication'),
            Tab(icon: Icon(Icons.payment_rounded, size: 20), text: 'Gateways'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Communications Gateway Roadmap
            _buildCommunicationsTab(theme, isDark),

            // Tab 2: Payment Gateways Roadmap
            _buildPaymentGatewaysTab(theme, isDark),
          ],
        ),
      ),
    );
  }

  // ─── TAB 1: COMMUNICATIONS ROADMAP ───────────────────────────────────
  Widget _buildCommunicationsTab(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Communications & Alerts',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              _buildRoadmapBadge(Colors.orange),
            ],
          ).animate().fadeIn(),
          const SizedBox(height: 6),
          const Text(
            'Configure third-party gateways to dispatch late alerts, notifications, and PDF billing receipts automatically.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ).animate(delay: 50.ms).fadeIn(),
          const SizedBox(height: 24),

          // ── Live SMS Settings entry ────────────────────────────────
          _buildSmsCard(theme).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),
          const SizedBox(height: 16),

          _buildRoadmapCard(
            theme: theme,
            title: 'SMTP / Email Settings',
            subtitle: 'SMTP Relay or Resend/SendGrid credentials',
            description: 'Enables custom organization emails for emailing repayment invoices, loan agreement booklets, and annual tax statements.',
            priority: 'P1',
            icon: Icons.email_outlined,
            color: Colors.blue,
          ).animate(delay: 130.ms).fadeIn().slideY(begin: 0.05, end: 0),
          const SizedBox(height: 16),

          _buildRoadmapCard(
            theme: theme,
            title: 'WhatsApp Business API',
            subtitle: 'Send official notifications directly to customer devices',
            description: 'Configure Meta developer token, Phone Number ID, and custom template schemas. Enables direct communication for overdue alerts.',
            priority: 'P2',
            icon: Icons.chat_bubble_outline_rounded,
            color: Colors.teal,
          ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.05, end: 0),

        ],
      ),
    );
  }

  // ─── TAB 2: GATEWAYS ROADMAP ─────────────────────────────────────────
  Widget _buildPaymentGatewaysTab(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Repayment Gateways',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              _buildRoadmapBadge(Colors.blueGrey),
            ],
          ).animate().fadeIn(),
          const SizedBox(height: 6),
          const Text(
            'Hook up localized digital checkout pipelines. Enables customers to do cashless repayments via automated UPI intents.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ).animate(delay: 50.ms).fadeIn(),
          const SizedBox(height: 24),

          _buildUpiConfigSection(theme).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),
          const SizedBox(height: 16),

          _buildRoadmapCard(
            theme: theme,
            title: 'Razorpay / PhonePe Integration',
            subtitle: 'Standardized digital checkout gateway',
            description: 'Provide live webhook secrets, public tokens, and checkout callbacks. Connect credit cards, netbanking, and digital wallets.',
            priority: 'P2',
            icon: Icons.payment_rounded,
            color: Colors.deepPurple,
          ).animate(delay: 130.ms).fadeIn().slideY(begin: 0.05, end: 0),
        ],
      ),
    );
  }

  // ─── SMS SETTINGS ENTRY CARD ──────────────────────────────────────

  Widget _buildSmsCard(ThemeData theme) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: InkWell(
        onTap: () => context.push('/settings/sms'),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.sms_rounded, color: Colors.green, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Local SMS',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Auto-send, SIM selection, reminders, and history',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UPI CONFIGURATION FORM ────────────────────────────────────────

  Widget _buildUpiConfigSection(ThemeData theme) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: Colors.green, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'UPI Direct Payments',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Configure merchant VPA for customer self-service UPI payments',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_loadingUpiConfig)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[            
            // VPA field
            TextFormField(
              controller: _upiVpaCtrl,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'UPI VPA',
                hintText: 'yourorg@bankupi',
                prefixIcon: Icon(Icons.alternate_email_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Merchant name field
            TextFormField(
              controller: _upiMerchantCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Merchant Name',
                hintText: 'Displayed on the customer UPI app',
                prefixIcon: Icon(Icons.storefront_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _savingUpi ? null : _saveUpi,
                icon: _savingUpi
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _savingUpi ? 'Saving UPI config…' : 'Save UPI Configuration',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Status indicator
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: _upiVpaCtrl.text.trim().isNotEmpty ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                _upiVpaCtrl.text.trim().isNotEmpty
                    ? 'VPA configured — customers can pay via UPI'
                    : 'No VPA configured — UPI payments disabled',
                style: TextStyle(
                  fontSize: 12,
                  color: _upiVpaCtrl.text.trim().isNotEmpty ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── REUSABLE WIDGETS ────────────────────────────────────────────────
  Widget _buildRoadmapBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'ROADMAP',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildRoadmapCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required String description,
    required String priority,
    required IconData icon,
    required Color color,
    bool isActive = false,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (priority == 'P1' ? Colors.orange : Colors.grey).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priority,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: priority == 'P1' ? Colors.orange : Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      isActive ? Icons.check_circle_rounded : Icons.construction_rounded,
                      size: 14,
                      color: isActive ? Colors.green : Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? 'Active — Production ready' : 'Development pipeline schedule.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? Colors.green : Colors.amber,
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
