import 'package:flutter/material.dart';

/// A searchable settings entry. Add new settings here to make them discoverable.
class SearchableSetting {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> keywords;
  final String route;

  const SearchableSetting({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.keywords,
    required this.route,
  });
}

/// Central registry of all searchable settings.
/// To add a new setting, simply append to [_settings].
class SettingsSearchRegistry {
  SettingsSearchRegistry._();

  static const List<SearchableSetting> _settings = [
    // ── Account & Personal ──
    SearchableSetting(
      id: 'profile',
      title: 'Profile Settings',
      subtitle: 'Name, phone, email, and security password',
      icon: Icons.person_outline_rounded,
      color: Color(0xFF4F46E5),
      keywords: ['profile', 'name', 'phone', 'email', 'password', 'account', 'personal', 'security password'],
      route: '/settings/profile',
    ),
    SearchableSetting(
      id: 'dark_mode',
      title: 'Dark Mode',
      subtitle: 'Switch interface theme between light and dark',
      icon: Icons.dark_mode_rounded,
      color: Color(0xFF1E293B),
      keywords: ['dark', 'theme', 'night', 'mode', 'light', 'appearance', 'interface'],
      route: '/settings',
    ),
    SearchableSetting(
      id: 'biometric',
      title: 'Biometric Authentication',
      subtitle: 'Fingerprint or Face ID login',
      icon: Icons.fingerprint_rounded,
      color: Color(0xFF7C3AED),
      keywords: ['biometric', 'fingerprint', 'face', 'id', 'login', 'auth', 'security', 'lock'],
      route: '/settings',
    ),
    SearchableSetting(
      id: 'notifications',
      title: 'Push Notifications',
      subtitle: 'Alerts on approvals and tasks',
      icon: Icons.notifications_active_outlined,
      color: Color(0xFFF59E0B),
      keywords: ['notification', 'alert', 'push', 'ping', 'notify', 'alarm'],
      route: '/settings',
    ),
    SearchableSetting(
      id: 'ai_chatbot',
      title: 'AI Assistant',
      subtitle: 'Toggle floating chatbot',
      icon: Icons.smart_toy_outlined,
      color: Color(0xFF06B6D4),
      keywords: ['ai', 'assistant', 'chatbot', 'chat', 'bot', 'help', 'ai assistant'],
      route: '/settings',
    ),

    // ── Organization ──
    SearchableSetting(
      id: 'organization',
      title: 'Organization Settings',
      subtitle: 'Brand identity, legal profile, address, compliance',
      icon: Icons.business_outlined,
      color: Colors.blue,
      keywords: ['organization', 'org', 'brand', 'company', 'business', 'legal', 'compliance', 'address'],
      route: '/settings/organization',
    ),
    SearchableSetting(
      id: 'org_profile',
      title: 'Organization Profile',
      subtitle: 'Company details and branding',
      icon: Icons.apartment_rounded,
      color: Colors.blueAccent,
      keywords: ['organization', 'profile', 'company', 'brand', 'logo', 'details'],
      route: '/settings/organization-profile',
    ),
    SearchableSetting(
      id: 'loan_products',
      title: 'Loan & Savings Products',
      subtitle: 'Loan schemes, savings plans, rates, limits',
      icon: Icons.account_balance_outlined,
      color: Colors.indigo,
      keywords: ['loan', 'savings', 'product', 'scheme', 'rate', 'interest', 'yield', 'limit', 'deposit', 'collection'],
      route: '/settings/products',
    ),

    // ── Integrations ──
    SearchableSetting(
      id: 'integrations',
      title: 'Integrations & APIs',
      subtitle: 'SMS, UPI, WhatsApp, and SMTP configuration',
      icon: Icons.integration_instructions_outlined,
      color: Colors.teal,
      keywords: ['integration', 'api', 'sms', 'upi', 'whatsapp', 'smtp', 'third party', 'connect'],
      route: '/settings/integrations',
    ),

    // ── Security ──
    SearchableSetting(
      id: 'security',
      title: 'Security Shield',
      subtitle: 'Audit logs, session locks, data exports',
      icon: Icons.security_rounded,
      color: Colors.orange,
      keywords: ['security', 'audit', 'log', 'session', 'lock', 'password', 'export', 'shield', 'compliance'],
      route: '/settings/security',
    ),
    SearchableSetting(
      id: 'activity_logs',
      title: 'Activity Logs',
      subtitle: 'View all user actions and audit trail',
      icon: Icons.history_rounded,
      color: Colors.orangeAccent,
      keywords: ['activity', 'log', 'audit', 'trail', 'history', 'action', 'event'],
      route: '/settings/activity-logs',
    ),

    // ── Utilities ──
    SearchableSetting(
      id: 'help',
      title: 'Help & Support',
      subtitle: 'FAQs, ticket creation, policies',
      icon: Icons.support_agent_rounded,
      color: Colors.blueGrey,
      keywords: ['help', 'support', 'faq', 'ticket', 'policy', 'legal', 'terms', 'privacy'],
      route: '/settings/help-center',
    ),
    SearchableSetting(
      id: 'report_issue',
      title: 'Report an Issue',
      subtitle: 'Submit support tickets to Super Admins',
      icon: Icons.bug_report_outlined,
      color: Colors.orange,
      keywords: ['bug', 'issue', 'report', 'glitch', 'ticket', 'support'],
      route: '/settings/report-issue',
    ),
    SearchableSetting(
      id: 'security_policies',
      title: 'Security Policies',
      subtitle: 'Password rules, 2FA, session locks',
      icon: Icons.shield_outlined,
      color: Colors.red,
      keywords: ['password', '2fa', 'two-factor', 'lock', 'session', 'security', 'retention'],
      route: '/settings/password-rules',
    ),
    SearchableSetting(
      id: 'legal_policies',
      title: 'Privacy Policy & Terms',
      subtitle: 'Legal disclosures and regulatory compliance',
      icon: Icons.policy_outlined,
      color: Colors.teal,
      keywords: ['privacy', 'policy', 'terms', 'legal', 'disclosure', 'refund'],
      route: '/settings/legal-policies',
    ),
    SearchableSetting(
      id: 'updates',
      title: 'Check for Updates',
      subtitle: 'See what\'s new and install latest version',
      icon: Icons.system_update_rounded,
      color: Colors.deepPurple,
      keywords: ['update', 'version', 'upgrade', 'latest', 'new', 'check'],
      route: '/settings/app-update',
    ),
    SearchableSetting(
      id: 'backup',
      title: 'Data Backup & Export',
      subtitle: 'Export data, create backups',
      icon: Icons.backup_rounded,
      color: Colors.green,
      keywords: ['backup', 'export', 'data', 'download', 'save', 'restore'],
      route: '/settings/backup',
    ),
    SearchableSetting(
      id: 'sign_out',
      title: 'Sign Out',
      subtitle: 'Terminate active session',
      icon: Icons.logout_rounded,
      color: Colors.redAccent,
      keywords: ['sign', 'out', 'logout', 'exit', 'terminate', 'session'],
      route: '/settings',
    ),
  ];

  /// Search settings by query string.
  static List<SearchableSetting> search(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    return _settings.where((s) {
      if (s.title.toLowerCase().contains(q)) return true;
      if (s.subtitle.toLowerCase().contains(q)) return true;
      return s.keywords.any((k) => k.contains(q));
    }).toList();
  }
}
