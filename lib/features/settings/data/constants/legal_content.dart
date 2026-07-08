import 'package:flutter/material.dart';

const kLegalLastUpdated = 'July 2026';

class LegalSection {
  final String title;
  final IconData icon;
  final String content;

  const LegalSection({
    required this.title,
    required this.icon,
    required this.content,
  });
}

const kPrivacyPolicySections = [
  LegalSection(
    title: 'Information We Collect',
    icon: Icons.storage_outlined,
    content: '''MicroFlow Pro collects the following information to provide financial management services:

• Organization data: Legal name, display name, GST/PAN numbers, address, and contact details
• User profiles: Name, email, phone number, role, and branch assignment
• Financial records: Loan details, repayment schedules, savings plans, and transaction history
• Field data: GPS coordinates during collection visits and check-in/out events
• Device metadata: App version, device type, and last activity timestamps
• Support tickets: Subject, description, and communication history

All data is stored securely in encrypted databases hosted on Supabase cloud infrastructure.''',
  ),
  LegalSection(
    title: 'How We Use Your Information',
    icon: Icons.settings_outlined,
    content: '''We use collected information for the following purposes:

• Providing financial management services (loan tracking, collections, savings)
• Generating analytics and performance reports for your organization
• Sending automated notifications via SMS, email, and WhatsApp
• Ensuring field compliance through GPS-tagged visit verification
• Maintaining audit logs for regulatory compliance
• Improving app performance and user experience
• Providing customer support through the in-app ticketing system''',
  ),
  LegalSection(
    title: 'Data Sharing & Third Parties',
    icon: Icons.share_outlined,
    content: '''We may share data with the following third parties only as necessary:

• Payment gateways (Razorpay, PhonePe, UPI) — for processing repayments
• Communication providers (SMS, WhatsApp Business API, SMTP) — for sending notifications
• Cloud infrastructure (Supabase, Google Drive) — for data storage and backups
• Analytics services — for aggregate usage statistics (no personally identifiable information)

We do NOT sell, rent, or trade your personal or organizational data to third parties for marketing purposes.''',
  ),
  LegalSection(
    title: 'Data Security',
    icon: Icons.security_outlined,
    content: '''We implement industry-standard security measures:

• All data transmitted over TLS 1.3 encrypted connections
• Row-Level Security (RLS) policies enforce role-based data access
• Sensitive credentials (API keys, passwords) are encrypted at rest
• Offline data stored on-device is encrypted using platform keychain
• Regular security audits and penetration testing
• Automatic session timeout and biometric authentication support
• Configurable password complexity and two-factor authentication''',
  ),
  LegalSection(
    title: 'Data Retention',
    icon: Icons.schedule_outlined,
    content: '''Your data is retained as follows:

• Active organization data: Retained while your account is active
• Audit logs: Configurable retention period (default 7 years per regulatory requirements)
• Support tickets: Retained for 2 years after resolution
• Backups: Retained according to your configured backup schedule and retention policy
• Account deletion: Upon request, all organization data is purged within 30 days

You can configure audit log retention in Settings > Security > Audit Log Retention.''',
  ),
  LegalSection(
    title: 'Your Rights',
    icon: Icons.how_to_reg_outlined,
    content: '''As a data subject, you have the right to:

• Access: Request a copy of all data associated with your account
• Rectification: Request correction of inaccurate personal data
• Erasure: Request deletion of your personal data (subject to legal retention requirements)
• Portability: Export your data in standard formats (JSON, CSV)
• Objection: Object to processing of your data for specific purposes

To exercise these rights, contact your organization administrator or submit a support ticket through the app.''',
  ),
];

const kTermsOfServiceSections = [
  LegalSection(
    title: 'Acceptance of Terms',
    icon: Icons.gavel_outlined,
    content: '''By accessing and using MicroFlow Pro, you agree to be bound by these Terms of Service. If you do not agree to these terms, you must not use the application.

These terms apply to all users including Executive Administrators, Branch Managers, Collection Agents, and End Customers of MicroFlow Pro.''',
  ),
  LegalSection(
    title: 'Service Description',
    icon: Icons.info_outline,
    content: '''MicroFlow Pro is a financial management platform designed for Micro-Finance Institutions (MFIs) and savings groups. The application provides:

• Loan management and EMI tracking
• Savings plan management
• Field collection management with GPS verification
• Staff performance tracking and gamification
• Administrative controls and audit logging
• Offline data collection with automatic synchronization

The service is provided "as is" and may be updated, modified, or discontinued at our discretion with reasonable notice.''',
  ),
  LegalSection(
    title: 'User Responsibilities',
    icon: Icons.person_outline,
    content: '''Users are responsible for:

• Maintaining the confidentiality of their login credentials
• Ensuring all financial data entered is accurate and complete
• Complying with applicable financial regulations in their jurisdiction
• Using the app in accordance with their organization's policies
• Reporting security vulnerabilities or bugs through proper channels
• Not attempting to circumvent security measures or access controls

Violation of these responsibilities may result in account suspension or termination.''',
  ),
  LegalSection(
    title: 'Financial Disclaimers',
    icon: Icons.account_balance_outlined,
    content: '''MicroFlow Pro is a management tool and does NOT:

• Provide financial advice or recommendations
• Guarantee loan repayment or investment returns
• Act as a financial intermediary or payment processor
• Replace compliance with local banking and financial regulations

Organizations using MicroFlow Pro are solely responsible for their financial operations, regulatory compliance, and customer relationships.''',
  ),
  LegalSection(
    title: 'Limitation of Liability',
    icon: Icons.shield_outlined,
    content: '''To the maximum extent permitted by law:

• MicroFlow Pro shall not be liable for indirect, incidental, or consequential damages
• Total liability shall not exceed the subscription fees paid in the preceding 12 months
• We are not liable for data loss resulting from force majeure events
• We are not responsible for third-party service interruptions (payment gateways, SMS providers)

Organizations should maintain independent data backups as a safeguard.''',
  ),
  LegalSection(
    title: 'Termination',
    icon: Icons.exit_to_app_outlined,
    content: '''Either party may terminate this agreement:

• By the organization: Contact support to initiate account deletion. Data will be purged within 30 days.
• By MicroFlow Pro: For violation of these terms, with 30 days notice to remediate
• Upon termination: Access to the application ceases immediately. Data export is available for 30 days post-termination.''',
  ),
];

const kDataProcessingSections = [
  LegalSection(
    title: 'Purpose of Processing',
    icon: Icons.sync_outlined,
    content: '''MicroFlow Pro processes personal and financial data solely for the purpose of providing financial management services to Micro-Finance Institutions. Data processing activities include:

• Loan origination, disbursement, and repayment tracking
• Savings plan enrollment and deposit management
• Staff performance monitoring and gamification
• Automated notification delivery (SMS, email, WhatsApp)
• Compliance audit logging and reporting
• Customer support and issue resolution''',
  ),
  LegalSection(
    title: 'Legal Basis for Processing',
    icon: Icons.balance_outlined,
    content: '''Data processing is based on:

• Contractual necessity: Processing required to deliver the financial management service
• Legitimate interest: Analytics, security monitoring, and service improvement
• Legal obligation: Audit logging and financial record retention as required by law
• Consent: Marketing communications and optional features (configurable by admin)''',
  ),
];

const kRefundPolicySections = [
  LegalSection(
    title: 'Subscription Refunds',
    icon: Icons.replay_outlined,
    content: '''Refund policy for MicroFlow Pro subscriptions:

• Annual subscriptions: Full refund within 30 days of purchase, pro-rata refund within 90 days
• Monthly subscriptions: Refund for current month if service is substantially unavailable
• No refund for: Feature usage, data storage, or third-party integration costs

Refund requests should be submitted through the in-app support ticketing system with subject "Refund Request".''',
  ),
  LegalSection(
    title: 'Processing Time',
    icon: Icons.timer_outlined,
    content: '''Refund processing details:

• Refund requests are reviewed within 5 business days
• Approved refunds are processed within 10-15 business days
• Refunds are issued to the original payment method
• You will receive email confirmation when the refund is processed''',
  ),
];
