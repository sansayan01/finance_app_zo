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
    title: 'What This App Is',
    icon: Icons.menu_book_outlined,
    content: '''MicroFlow Pro is a private digital record-keeping (book-keeping) tool for individual money-lenders. It helps you keep track of who you have lent money to, the interest accrued, and the repayments you have collected.

MicroFlow Pro is NOT a lending platform, an NBFC, or a bank. It does not lend money, hold funds, or process payments. It is simply a digital ledger that stores the records you choose to enter.''',
  ),
  LegalSection(
    title: 'Information We Collect',
    icon: Icons.storage_outlined,
    content: '''We collect only what is needed to run the app for you:

• Your account details: Name, email, phone number, and login credentials
• Records you enter: Borrower name, phone number, loan amount, interest terms, and repayment history — all typed in by you
• Device metadata: App version, device type, and last activity timestamps
• Support tickets: Subject, description, and communication history

Borrower information is supplied entirely by you, the lender. We do not independently collect, buy, or gather any data about your borrowers. All data is stored securely in encrypted databases hosted on Supabase cloud infrastructure.''',
  ),
  LegalSection(
    title: 'We Do Not Verify Borrower Identity',
    icon: Icons.person_off_outlined,
    content: '''By design, MicroFlow Pro does NOT verify the identity of your borrowers. We do not perform Aadhaar, PAN, CIBIL, or any other identity or credit check.

Money-lending between individuals is based on your own trust and judgement. The app records the details you enter as-is. Confirming who your borrower is, and whether to lend, is entirely your decision and responsibility.''',
  ),
  LegalSection(
    title: 'How We Use Your Information',
    icon: Icons.settings_outlined,
    content: '''We use your information only to provide the record-keeping service:

• Storing and displaying the records you enter
• Calculating interest and repayment summaries from your data
• Sending optional reminders (via SMS) that YOU choose to trigger
• Backing up your ledger to your configured storage
• Improving app performance and reliability
• Providing customer support through the in-app ticketing system

We do not use your data, or your borrowers' data, for advertising or profiling.''',
  ),
  LegalSection(
    title: 'Data Sharing & Third Parties',
    icon: Icons.share_outlined,
    content: '''We share data only with the service providers needed to run the app:

• Cloud infrastructure (Supabase, Google Drive) — for secure data storage and backups
• SMS provider — only when you choose to send a reminder to a borrower
• Analytics services — aggregate, anonymised usage statistics only (no personal information)

We do NOT sell, rent, or trade your data or your borrowers' data to anyone for marketing purposes. We are not a payment processor and do not share data with payment gateways.''',
  ),
  LegalSection(
    title: 'Data Security',
    icon: Icons.security_outlined,
    content: '''We implement industry-standard security measures:

• All data transmitted over TLS 1.3 encrypted connections
• Row-Level Security (RLS) policies ensure only you can access your data
• Sensitive credentials (API keys, passwords) are encrypted at rest
• Offline data stored on-device is encrypted using platform keychain
• Automatic session timeout and biometric authentication support
• Configurable password complexity and two-factor authentication''',
  ),
  LegalSection(
    title: 'Data Retention',
    icon: Icons.schedule_outlined,
    content: '''Your data is retained as follows:

• Active account data: Retained for as long as your account is active
• Support tickets: Retained for 2 years after resolution
• Backups: Retained according to the backup schedule you configure
• Account deletion: On request, all your data is permanently purged within 30 days

You are in control of your records — you can edit or delete individual entries at any time.''',
  ),
  LegalSection(
    title: 'Your Control Over Your Data',
    icon: Icons.how_to_reg_outlined,
    content: '''You control the data in your ledger. You can:

• Access: View all data associated with your account at any time
• Correct: Edit any record that is inaccurate
• Delete: Remove individual records or request full account deletion
• Export: Download your data in standard formats (JSON, CSV)

To request a full data export or account deletion, submit a support ticket through the app.''',
  ),
];

const kTermsOfServiceSections = [
  LegalSection(
    title: 'Acceptance of Terms',
    icon: Icons.gavel_outlined,
    content: '''By accessing and using MicroFlow Pro, you agree to be bound by these Terms of Service. If you do not agree to these terms, you must not use the application.

These terms apply to you as the individual user (lender) of MicroFlow Pro.''',
  ),
  LegalSection(
    title: 'What MicroFlow Pro Is',
    icon: Icons.info_outline,
    content: '''MicroFlow Pro is a private digital record-keeping tool for individual money-lenders. The application lets you:

• Record the loans you have given, including amount and interest terms
• Track repayments you have collected
• View interest accrued and outstanding balances
• Keep an organised, searchable ledger of your borrowers
• Optionally send repayment reminders and back up your records

The service is provided "as is" and may be updated, modified, or discontinued at our discretion with reasonable notice.''',
  ),
  LegalSection(
    title: 'Not a Lender, NBFC, or Bank',
    icon: Icons.account_balance_outlined,
    content: '''MicroFlow Pro is only a record-keeping tool. It is NOT:

• A lender — we do not lend money to you or anyone
• An NBFC, bank, or financial institution
• A lending marketplace or intermediary
• A payment processor — we do not move, hold, or handle any money
• A provider of credit scoring or identity verification

All lending decisions, funds, agreements, and dealings are strictly between you and your borrowers. MicroFlow Pro is not a party to any loan you record in the app.''',
  ),
  LegalSection(
    title: 'Your Legal Responsibility & Compliance',
    icon: Icons.balance_outlined,
    content: '''You, the user, are SOLELY responsible for the legality of your lending activity. This includes, but is not limited to:

• Complying with all applicable local, state, and national money-lending laws
• Obtaining any money-lender licence or registration required in your jurisdiction
• Observing any legal limits on interest rates and charges that apply to you
• Ensuring your dealings with borrowers are lawful and fair

MicroFlow Pro does NOT provide legal, financial, tax, or regulatory advice, and nothing in the app should be treated as such. Laws differ by state and change over time — consult a qualified professional about your obligations. Using this app does not make your lending lawful, and we make no representation that it does.''',
  ),
  LegalSection(
    title: 'User Responsibilities',
    icon: Icons.person_outline,
    content: '''You are responsible for:

• Maintaining the confidentiality of your login credentials
• Ensuring the records you enter are accurate and lawful
• Obtaining any consent required to store your borrowers' information
• Using the app in compliance with the law in your jurisdiction
• Reporting security vulnerabilities or bugs through proper channels
• Not attempting to circumvent security measures or access controls

Violation of these responsibilities may result in account suspension or termination.''',
  ),
  LegalSection(
    title: 'Limitation of Liability',
    icon: Icons.shield_outlined,
    content: '''To the maximum extent permitted by law:

• MicroFlow Pro shall not be liable for indirect, incidental, or consequential damages
• We are not liable for any dispute, loss, or default arising from loans you record
• Total liability shall not exceed the subscription fees paid in the preceding 12 months
• We are not liable for data loss resulting from force majeure events
• We are not responsible for third-party service interruptions (SMS providers, cloud storage)

You should maintain independent backups of your records as a safeguard.''',
  ),
  LegalSection(
    title: 'Termination',
    icon: Icons.exit_to_app_outlined,
    content: '''Either party may terminate this agreement:

• By you: Contact support to initiate account deletion. Your data will be purged within 30 days.
• By MicroFlow Pro: For violation of these terms, with 30 days notice to remediate
• Upon termination: Access to the application ceases immediately. Data export is available for 30 days post-termination.''',
  ),
];

const kDataProcessingSections = [
  LegalSection(
    title: 'How Your Data Is Handled',
    icon: Icons.sync_outlined,
    content: '''MicroFlow Pro processes the information in your ledger for one purpose only: to provide you with a working record-keeping tool. This means:

• Storing and displaying the records you enter
• Calculating interest and repayment summaries from your data
• Sending reminders only when you choose to trigger them
• Backing up your data to the storage you configure
• Resolving support requests you raise

We act as a custodian of the data you store — we do not analyse it, sell it, or use it for any purpose beyond running the app for you.''',
  ),
  LegalSection(
    title: 'Borrower Data Is Yours',
    icon: Icons.folder_shared_outlined,
    content: '''Any borrower information in the app is entered by you and belongs to your records. You decide what to record and how long to keep it.

Because you collect and enter this information directly, you are responsible for handling it fairly and for obtaining any consent that the law in your area may require. MicroFlow Pro simply stores it securely on your behalf.''',
  ),
];

const kRefundPolicySections = [
  LegalSection(
    title: 'Subscription Refunds',
    icon: Icons.replay_outlined,
    content: '''Refund policy for MicroFlow Pro subscriptions:

• Annual subscriptions: Full refund within 30 days of purchase, pro-rata refund within 90 days
• Monthly subscriptions: Refund for the current month if service is substantially unavailable
• No refund for: Feature usage, data storage, or third-party integration costs

Refund requests should be submitted through the in-app support ticketing system with the subject "Refund Request".''',
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
