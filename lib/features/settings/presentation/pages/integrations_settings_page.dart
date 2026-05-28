import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

class IntegrationsSettingsPage extends ConsumerStatefulWidget {
  const IntegrationsSettingsPage({super.key});

  @override
  ConsumerState<IntegrationsSettingsPage> createState() => _IntegrationsSettingsPageState();
}

class _IntegrationsSettingsPageState extends ConsumerState<IntegrationsSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

          _buildRoadmapCard(
            theme: theme,
            title: 'SMS Gateway',
            subtitle: 'Twilio / MSG91 API configuration',
            description: 'Provide API endpoints, credentials, and Sender IDs to broadcast automatic OTP and loan disbursement alerts to mobile nodes.',
            priority: 'P1',
            icon: Icons.sms_outlined,
            color: Colors.green,
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),
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

          _buildRoadmapCard(
            theme: theme,
            title: 'UPI Organization Hook',
            subtitle: 'Direct bank transfer settings',
            description: 'Store direct merchant Virtual Payment Addresses (VPA) and automated bank codes. Connect direct QR generators inside collection receipts.',
            priority: 'P2',
            icon: Icons.qr_code_2_rounded,
            color: Colors.indigo,
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),
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
                const Row(
                  children: [
                    Icon(Icons.construction_rounded, size: 14, color: Colors.amber),
                    SizedBox(width: 6),
                    Text(
                      'Development pipeline schedule.',
                      style: TextStyle(fontSize: 12, color: Colors.amber),
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
