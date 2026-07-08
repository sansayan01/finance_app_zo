const kFaqCategories = [
  'Getting Started',
  'Loans & Disbursements',
  'Collections & Payments',
  'Savings & Deposits',
  'Staff & Operations',
  'Troubleshooting',
];

class FaqItem {
  final String question;
  final String answer;
  final String category;

  const FaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

const kFaqItems = [
  // ─── Getting Started ─────────────────────────────────────────────
  FaqItem(
    question: 'How do I set up my organization?',
    answer:
        'Navigate to Settings > Organization Settings. Fill in your legal name, display name, compliance details (GST/PAN), address, and locale preferences. Save to apply branding and configuration across all members.',
    category: 'Getting Started',
  ),
  FaqItem(
    question: 'How do I add staff members?',
    answer:
        'Go to Users from the admin dashboard. Tap "Add User" and fill in their name, email, phone, and assign a role (Branch Manager, Staff, or Collection Agent). They will receive login credentials.',
    category: 'Getting Started',
  ),
  FaqItem(
    question: 'How do I configure SMS and email alerts?',
    answer:
        'Go to Settings > Integrations & Third-Party APIs. Under the Communication tab, configure your SMS provider (local SIM or API), email provider (SMTP or Resend), and WhatsApp Business API. Use the "Send Test" buttons to verify each channel.',
    category: 'Getting Started',
  ),
  FaqItem(
    question: 'What is the difference between Executive Admin and Branch Manager?',
    answer:
        'Executive Admin has full organization-level access — managing all branches, staff, loans, and settings. Branch Manager operates within their assigned branch — managing branch staff, approving loans, and viewing branch-level analytics.',
    category: 'Getting Started',
  ),

  // ─── Loans & Disbursements ───────────────────────────────────────
  FaqItem(
    question: 'How do I create a new loan for a customer?',
    answer:
        'Go to Loans > New Loan. Select the customer, choose a loan product, enter the principal amount, interest rate, tenure, and repayment frequency. The system auto-generates the EMI schedule upon disbursement.',
    category: 'Loans & Disbursements',
  ),
  FaqItem(
    question: 'How are EMIs calculated?',
    answer:
        'EMIs are calculated using the reducing balance method. The formula considers principal, annual interest rate, and tenure. Late penalties are applied per your configured penalty percentage after the grace period.',
    category: 'Loans & Disbursements',
  ),
  FaqItem(
    question: 'Can I modify a loan after disbursement?',
    answer:
        'You can restructure a loan (change tenure, swap rates) with proper approval. Foreclosure is available for full early settlement with applicable foreclosure charges. All modifications are logged in the audit trail.',
    category: 'Loans & Disbursements',
  ),
  FaqItem(
    question: 'What happens when a loan is overdue?',
    answer:
        'Overdue loans appear in the staff dashboard under "Overdue Collections." The system sends automated SMS/WhatsApp reminders. Late penalties are calculated based on your configured penalty percentage and grace period.',
    category: 'Loans & Disbursements',
  ),

  // ─── Collections & Payments ──────────────────────────────────────
  FaqItem(
    question: 'How do staff record a collection?',
    answer:
        'Staff tap "Record Payment" on the collection list, select the customer and loan, enter the amount, choose payment mode (Cash, UPI, Bank Transfer), and submit. GPS coordinates are captured automatically for field verification.',
    category: 'Collections & Payments',
  ),
  FaqItem(
    question: 'What payment modes are supported?',
    answer:
        'The app supports Cash, UPI (with QR code generation), Bank Transfer, and Cheque. UPI payments can be configured with your organization\'s merchant VPA for customer self-service payments.',
    category: 'Collections & Payments',
  ),
  FaqItem(
    question: 'How does offline collection work?',
    answer:
        'When there is no internet, collections are queued locally on the device. The app shows a sync badge with pending count. When connectivity returns, queued collections auto-sync to the server. All offline data is encrypted on-device.',
    category: 'Collections & Payments',
  ),
  FaqItem(
    question: 'How do I generate a payment receipt?',
    answer:
        'After recording a collection, a receipt is automatically generated. Staff can share it via SMS, WhatsApp, or download as PDF. Receipts include loan details, amount paid, remaining balance, and date.',
    category: 'Collections & Payments',
  ),

  // ─── Savings & Deposits ──────────────────────────────────────────
  FaqItem(
    question: 'How do savings plans work?',
    answer:
        'Savings plans define fixed deposit amounts, interest yields, and maturity periods. Members enroll in a plan and make periodic deposits. Interest accrues based on the configured yield rate and is paid at maturity.',
    category: 'Savings & Deposits',
  ),
  FaqItem(
    question: 'Can members withdraw savings before maturity?',
    answer:
        'Early withdrawal terms depend on your organization\'s policy configured in the savings plan. Typically, a reduced interest rate applies for premature withdrawal. The maturity date and terms are shown in the member\'s savings dashboard.',
    category: 'Savings & Deposits',
  ),

  // ─── Staff & Operations ──────────────────────────────────────────
  FaqItem(
    question: 'How does the gamification system work?',
    answer:
        'Staff earn streaks for daily collections, unlock achievements for milestones, and compete on leaderboards. Streaks reset if a day is missed. Achievements cover collection volume, customer visits, and consistency targets.',
    category: 'Staff & Operations',
  ),
  FaqItem(
    question: 'How do field visits work?',
    answer:
        'Staff use the "Visit Check-in" feature to log customer visits. GPS coordinates and timestamps are captured. Check-in and check-out times are recorded for compliance and performance tracking.',
    category: 'Staff & Operations',
  ),
  FaqItem(
    question: 'How do I view staff performance?',
    answer:
        'Go to Analytics > Staff Performance. View collection totals, visit counts, streak data, and achievement progress per staff member. Filter by date range, branch, or individual agent.',
    category: 'Staff & Operations',
  ),

  // ─── Troubleshooting ─────────────────────────────────────────────
  FaqItem(
    question: 'The app is slow or unresponsive. What should I do?',
    answer:
        'Try these steps: 1) Force close and reopen the app. 2) Check your internet connection. 3) Clear the app cache from your device settings. 4) Ensure you are running the latest version from Settings > Check for Updates.',
    category: 'Troubleshooting',
  ),
  FaqItem(
    question: 'My data is not syncing. How do I fix it?',
    answer:
        'Check the sync badge in the bottom navigation. If it shows pending items, ensure you have internet connectivity. Tap the sync badge to force a manual sync. If issues persist, log out and log back in.',
    category: 'Troubleshooting',
  ),
  FaqItem(
    question: 'I forgot my password. How do I reset it?',
    answer:
        'Contact your Branch Manager or Executive Admin to reset your password from the User Management section. If you are the Executive Admin, contact the platform Super Admin for a password reset.',
    category: 'Troubleshooting',
  ),
  FaqItem(
    question: 'How do I report a bug or issue?',
    answer:
        'Go to Settings > Support > Report a System Glitch. Fill in the subject, describe the issue, set priority, and submit. Our support team will review and respond through the in-app ticketing system.',
    category: 'Troubleshooting',
  ),
];
