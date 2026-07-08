import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/constants/legal_content.dart';

class LegalPoliciesPage extends StatelessWidget {
  const LegalPoliciesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Policies & Disclosures'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legal Policies',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 4),
            Text(
              'Official disclosures, terms, and regulatory compliance documents.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
            ).animate().fadeIn(delay: 50.ms),
            const SizedBox(height: 4),
            Text(
              'Last updated: $kLegalLastUpdated',
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Privacy Policy ───────────────────────────────────────
            _buildPolicySection(
              context: context,
              theme: theme,
              title: 'Privacy Policy',
              subtitle: 'How we collect, use, and protect your data',
              icon: Icons.privacy_tip_outlined,
              color: Colors.blue,
              sections: kPrivacyPolicySections,
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.04, end: 0),
            const SizedBox(height: 16),

            // ─── Terms of Service ─────────────────────────────────────
            _buildPolicySection(
              context: context,
              theme: theme,
              title: 'Terms of Service',
              subtitle: 'Rules governing the use of MicroFlow Pro',
              icon: Icons.gavel_outlined,
              color: Colors.indigo,
              sections: kTermsOfServiceSections,
            ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.04, end: 0),
            const SizedBox(height: 16),

            // ─── Data Processing ──────────────────────────────────────
            _buildPolicySection(
              context: context,
              theme: theme,
              title: 'Data Processing Agreement',
              subtitle: 'Legal basis for data processing activities',
              icon: Icons.sync_outlined,
              color: Colors.teal,
              sections: kDataProcessingSections,
            ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.04, end: 0),
            const SizedBox(height: 16),

            // ─── Refund Policy ────────────────────────────────────────
            _buildPolicySection(
              context: context,
              theme: theme,
              title: 'Refund Policy',
              subtitle: 'Subscription refund terms and conditions',
              icon: Icons.replay_outlined,
              color: Colors.orange,
              sections: kRefundPolicySections,
            ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.04, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<LegalSection> sections,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
          ),
          children: sections.map((section) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(section.icon, size: 16, color: color),
                      const SizedBox(width: 8),
                      Text(
                        section.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.content,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                  const Divider(height: 24),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
