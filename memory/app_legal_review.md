# App Legal Content Review — India Fintech Compliance
**Date:** 2026-07-19
**Scope:** Read-only analysis of `lib/features/settings/data/constants/legal_content.dart` + render/linkage context. No app files edited. Proposed content below is **DRAFT FOR LAWYER REVIEW** — not legal advice.

---

## 1. Current State
Existing `legal_content.dart` is generic boilerplate (GDPR-flavoured, "as is" SaaS language) with **zero India-specific statutory references**. It does not mention DPDP Act 2023, data localisation, NBFC-vs-platform disclaimer, RBI digital-lending collection conduct rules, Grievance/Data Protection Officers, borrower consent, or GST.

---

## 2. Gaps Found (India Compliance)

**Privacy Policy**
- No DPDP Act 2023 reference, no "Data Fiduciary" vs "Data Processor" role split (MicroFlow is a **processor** for NBFC-client data, **fiduciary** for its own platform/tenant-admin data).
- No explicit **borrower consent** mechanism language before collection of financial/GPS data.
- No **data localisation** statement (Supabase India region / servers in India).
- No **breach notification** timeline (DPDP: notify Board + affected users "as soon as possible" / 72h expectation).
- No **Grievance Redressal Officer (GRO)** + **Data Protection Officer (DPO)** names/emails/response SLA.
- "Rights" section lacks **right to erasure** specifics + how to withdraw consent + complaint to Data Protection Board.
- GPS "field data" collected without stating purpose-limitation / consent basis.

**Terms of Service**
- "Financial Disclaimers" says we don't act as intermediary/processor but **does not clearly state MicroFlow is a technology platform, NOT an NBFC**, and that **lending/disbursement/collections are done by RBI-registered NBFC clients**. Critical for liability + RBI fair-practice posture.
- No reference to **RBI Master Direction on Digital Lending (2022)** or fair-recovery conduct.
- No governing law / jurisdiction (should be India, appropriate courts).

**Data Processing Agreement**
- Two legal-basis bullets contradict India law: "Consent: Marketing ... configurable" — fine, but no **consent manager / notice** language, no **children's data** exclusion, no mention that for financial data of borrowers the **NBFC is the fiduciary** and MicroFlow processes on its documented instructions.
- No cross-border transfer clause (reinforces localisation).

**Refund Policy**
- No **GST** note (OIDAR 18% on SaaS exported to/within India; refunds typically exclude GST already remitted, or are GST-inclusive — needs clarity).
- No mention of **non-refundable setup/onboarding / third-party pass-through fees** beyond a single line.

**Also relevant (not a content gap, but a delivery gap):**
- `searchable_settings.dart` + `security_compliance_page.dart` expose legal/security entry points but there is **no in-app "Collection Practices / Fair Recovery" disclosure** and **no GRO/DPO contact card** anywhere in the Settings tree. Recommend adding a `kCollectionPracticesSections` constant and a contact block (see change list).

---

## 3. Proposed Improved Dart Constants
> NOTE: placeholders `[GRO_NAME]`, `[GRO_EMAIL]`, `[DPO_NAME]`, `[DPO_EMAIL]`, `[MICROFLOW_LEGAL_ENTITY]`, `[SUPABASE_REGION]` must be filled by Sayan / legal before publish.

```dart
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

/// ===========================================================================
/// PRIVACY POLICY — India DPDP Act 2023 aligned (DRAFT FOR LAWYER REVIEW)
/// ===========================================================================
const kPrivacyPolicySections = [
  LegalSection(
    title: 'Our Role: Data Fiduciary & Data Processor',
    icon: Icons.balance_outlined,
    content: '''MicroFlow Pro ("MicroFlow", "[MICROFLOW_LEGAL_ENTITY]") operates as a technology platform for Micro-Finance Institutions (MFIs) and savings groups.

• For data you enter about your own organisation and staff (tenant/administrator data), MicroFlow acts as the **Data Fiduciary** and is responsible for complying with the Digital Personal Data Protection Act, 2023 (DPDP Act).
• For borrower/member financial data entered on behalf of our MFI/NBFC clients, the **registered NBFC or MFI is the Data Fiduciary** and MicroFlow acts as a **Data Processor**, processing that data only on the fiduciary's documented instructions.

This distinction governs who is accountable to you and to the Data Protection Board of India.''',
  ),
  LegalSection(
    title: 'Consent & Borrower Data Collection',
    icon: Icons.verified_user_outlined,
    content: '''We collect personal and financial data only with a lawful basis under the DPDP Act, 2023.

• Where you are a borrower/member, your data is collected by the lending NBFC/MFI with your **free, specific, informed, and unambiguous consent**, given at the point of loan origination or enrolment.
• Field/collection data (including GPS coordinates captured during visits and check-in/out events) is collected solely to verify field activity and is processed on the NBFC's instructions.
• You may **withdraw consent** at any time; withdrawal does not affect lawful processing done before withdrawal. To withdraw, contact your lending institution or the Grievance Redressal Officer listed below.

We do NOT collect data from children (under 18) through this platform.''',
  ),
  LegalSection(
    title: 'Information We Collect',
    icon: Icons.storage_outlined,
    content: '''MicroFlow Pro collects the following to provide financial management services:

• Organization data: Legal name, display name, GST/PAN numbers, registered address, and contact details
• User profiles: Name, email, phone number, role, and branch assignment
• Financial records: Loan details, repayment schedules, savings plans, and transaction history
• Field data: GPS coordinates during collection visits and check-in/out events (with consent)
• Device metadata: App version, device type, and last activity timestamps
• Support tickets: Subject, description, and communication history

All data is stored in encrypted databases hosted on Supabase cloud infrastructure.**''',
  ),
  LegalSection(
    title: 'Data Localisation & Storage Location',
    icon: Icons.cloud_done_outlined,
    content: '''In accordance with Indian data-protection requirements and RBI expectations for financial data, personal and financial data of Indian users is **stored on servers located within India** ([SUPABASE_REGION] region).

We do not transfer this data outside India except where strictly required for service operation and then only with appropriate contractual and technical safeguards. Cross-border transfer, if any, is performed on the fiduciary's instructions and with adequate protection.''',
  ),
  LegalSection(
    title: 'How We Use Your Information',
    icon: Icons.settings_outlined,
    content: '''We use collected information for the following purposes:

• Providing financial management services (loan tracking, collections, savings)
• Generating analytics and performance reports for your organization
• Sending automated notifications via SMS, email, and WhatsApp (with consent)
• Ensuring field compliance through GPS-tagged visit verification
• Maintaining audit logs for regulatory compliance
• Improving app performance and user experience
• Providing customer support through the in-app ticketing system''',
  ),
  LegalSection(
    title: 'Data Sharing & Third Parties',
    icon: Icons.share_outlined,
    content: '''We may share data with the following third parties only as necessary and on a need-to-know basis:

• Payment gateways (Razorpay, PhonePe, UPI) — for processing repayments
• Communication providers (SMS, WhatsApp Business API, SMTP) — for sending notifications
• Cloud infrastructure (Supabase, Google Drive) — for data storage and backups within India
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
    title: 'Data Retention & Erasure',
    icon: Icons.schedule_outlined,
    content: '''Retention is governed by the DPDP Act and applicable financial-record rules:

• Active organization data: Retained while your account is active
• Audit logs: Configurable retention period (default 7 years per regulatory requirements)
• Support tickets: Retained for 2 years after resolution
• Backups: Retained according to your configured backup schedule and retention policy
• Account/erasure requests: On a valid request we delete or purge personal data within **30 days**, subject to legal retention obligations (e.g. financial records the NBFC must keep under law)

You can configure audit log retention in Settings > Security > Audit Log Retention.''',
  ),
  LegalSection(
    title: 'Your Rights (DPDP Act, 2023)',
    icon: Icons.how_to_reg_outlined,
    content: '''As a data principal, you have the right to:

• **Access:** Request a summary of your personal data and its processing
• **Correction & Erasure:** Request correction of inaccurate data and erasure of data no longer necessary
• **Grievance Redressal:** Lodge a complaint with our Grievance Redressal Officer (details below)
• **Nomination:** Nominate another person to exercise your rights in the event of death or incapacity
• **Portability:** Export your data in standard formats (JSON, CSV) where technically feasible
• **Withdraw Consent:** Object to or withdraw consent for processing

To exercise these rights, contact your organization administrator, the Grievance Redressal Officer below, or submit a support ticket through the app. If unsatisfied, you may complain to the **Data Protection Board of India**.''',
  ),
  LegalSection(
    title: 'Breach Notification',
    icon: Icons.warning_amber_outlined,
    content: '''In the event of a personal-data breach, MicroFlow will:

• Notify the **Data Protection Board of India** without undue delay and, where feasible, within 72 hours of becoming aware;
• Inform affected users whose rights are likely to be harmed, with guidance on protective steps;
• Maintain an internal incident-response and breach-register process.

As a processor, MicroFlow also notifies the relevant NBFC/MFI fiduciary promptly so it can meet its own statutory obligations.''',
  ),
  LegalSection(
    title: 'Grievance Redressal & Data Protection Officers',
    icon: Icons.support_agent_outlined,
    content: '''We have appointed the following officers as required under the DPDP Act, 2023 and RBI guidelines:

**Grievance Redressal Officer (GRO)**
• Name: [GRO_NAME]
• Email: [GRO_EMAIL]
• Response timeline: Acknowledged within 48 hours; resolved or escalated within **30 days** of receipt.

**Data Protection Officer (DPO)**
• Name: [DPO_NAME]
• Email: [DPO_EMAIL]

You may contact either officer for any concern about how your personal data is processed, or to exercise your rights under the DPDP Act, 2023.''',
  ),
];

/// ===========================================================================
/// TERMS OF SERVICE — India aligned (DRAFT FOR LAWYER REVIEW)
/// ===========================================================================
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
    title: 'Technology Platform — Not an NBFC',
    icon: Icons.account_balance_outlined,
    content: '''**MicroFlow Pro is a technology platform, NOT a Non-Banking Financial Company (NBFC).**

• MicroFlow does not itself lend, disburse, or collect loans. All lending, disbursement, and recovery of credit is undertaken by our clients who are **RBI-registered NBFCs or MFIs**.
• MicroFlow merely provides the software infrastructure that such registered entities use to manage their own operations.
• Loan approvals, interest rates, fees, and recovery actions are determined solely by the respective NBFC/MFI in compliance with RBI regulations. MicroFlow bears no liability for the credit decisions or recovery conduct of those entities.
• Nothing in this platform constitutes a financial product offered by MicroFlow.''',
  ),
  LegalSection(
    title: 'User Responsibilities',
    icon: Icons.person_outline,
    content: '''Users are responsible for:

• Maintaining the confidentiality of their login credentials
• Ensuring all financial data entered is accurate and complete
• Complying with applicable financial regulations in their jurisdiction (including RBI fair-practice and digital-lending guidelines)
• Using the app in accordance with their organization's policies
• Reporting security vulnerabilities or bugs through proper channels
• Not attempting to circumvent security measures or access controls
• Conducting all borrower interactions (including recovery) in line with the Collection Practices disclosed in this app

Violation of these responsibilities may result in account suspension or termination.''',
  ),
  LegalSection(
    title: 'Financial Disclaimers',
    icon: Icons.account_balance_wallet_outlined,
    content: '''MicroFlow Pro is a management tool and does NOT:

• Provide financial advice or recommendations
• Guarantee loan repayment or investment returns
• Act as a financial intermediary, lender, or payment processor in its own capacity
• Replace compliance with RBI banking and financial regulations, which remain the sole responsibility of the lending NBFC/MFI

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

Organizations should maintain independent data backups as a safeguard. Nothing in this clause limits liability that cannot be excluded under applicable Indian law.''',
  ),
  LegalSection(
    title: 'Governing Law & Jurisdiction',
    icon: Icons.gavel_rounded,
    content: '''These Terms are governed by the laws of India. The courts at [MICROFLOW_REGISTRED_OFFICE_CITY] shall have exclusive jurisdiction over any dispute arising out of or in connection with the use of MicroFlow Pro, without prejudice to the right of the Grievance Redressal Officer to first attempt resolution.''',
  ),
  LegalSection(
    title: 'Termination',
    icon: Icons.exit_to_app_outlined,
    content: '''Either party may terminate this agreement:

• By the organization: Contact support to initiate account deletion. Data will be purged within 30 days (subject to lawful retention).
• By MicroFlow Pro: For violation of these terms, with 30 days notice to remediate
• Upon termination: Access to the application ceases immediately. Data export is available for 30 days post-termination.''',
  ),
];

/// ===========================================================================
/// DATA PROCESSING AGREEMENT — DPDP aligned (DRAFT FOR LAWYER REVIEW)
/// ===========================================================================
const kDataProcessingSections = [
  LegalSection(
    title: 'Parties & Roles',
    icon: Icons.people_outline,
    content: '''This Data Processing Agreement governs processing performed by MicroFlow Pro on behalf of the lending NBFC/MFI (the Data Fiduciary) and for its own tenant-administrator data (where MicroFlow is Fiduciary).

• The NBFC/MFI remains the Data Fiduciary accountable to borrowers under the DPDP Act, 2023.
• MicroFlow acts as a Data Processor engaged by the fiduciary and processes personal data only on the fiduciary's documented instructions, or as required by Indian law.''',
  ),
  LegalSection(
    title: 'Purpose of Processing',
    icon: Icons.sync_outlined,
    content: '''MicroFlow Pro processes personal and financial data solely for the purpose of providing financial management services to Micro-Finance Institutions. Data processing activities include:

• Loan origination, disbursement, and repayment tracking (on NBFC instructions)
• Savings plan enrolment and deposit management
• Staff performance monitoring and gamification
• Automated notification delivery (SMS, email, WhatsApp)
• Compliance audit logging and reporting
• Customer support and issue resolution''',
  ),
  LegalSection(
    title: 'Legal Basis for Processing',
    icon: Icons.balance_outlined,
    content: '''Data processing is based on:

• **Consent:** The primary basis for borrower personal data, obtained by the NBFC/MFI at origination/enrolment
• **Contractual necessity:** Processing required to deliver the financial management service
• **Legitimate interest:** Analytics, security monitoring, and service improvement
• **Legal obligation:** Audit logging and financial-record retention as required by Indian law
• **Processor instructions:** For NBFC-data, processing follows the fiduciary's lawful instructions''',
  ),
  LegalSection(
    title: 'Sub-Processing & Data Location',
    icon: Icons.hub_outlined,
    content: '''• MicroFlow may engage sub-processors (e.g. Supabase for hosting, Razorpay/PhonePe for payments, SMS/WhatsApp gateways) only with contractual data-protection obligations equivalent to this agreement.
• Personal data of Indian users is hosted **within India** ([SUPABASE_REGION] region) in line with localisation expectations.
• Any sub-processor engagement that requires cross-border transfer is performed only on the fiduciary's instructions with adequate safeguards.''',
  ),
  LegalSection(
    title: 'Security, Breach & Audit',
    icon: Icons.lock_outline,
    content: '''• MicroFlow implements TLS 1.3 in transit, encryption at rest, RLS-based access control, and regular audits/penetration testing.
• In a personal-data breach, MicroFlow notifies the fiduciary without undue delay and assists the fiduciary in meeting its DPDP notification duties to the Data Protection Board and affected users.
• The fiduciary may request evidence of MicroFlow's processing practices reasonable to demonstrate compliance.''',
  ),
];

/// ===========================================================================
/// REFUND POLICY — with GST/OIDAR note (DRAFT FOR LAWYER REVIEW)
/// ===========================================================================
const kRefundPolicySections = [
  LegalSection(
    title: 'Subscription Refunds',
    icon: Icons.replay_outlined,
    content: '''Refund policy for MicroFlow Pro subscriptions:

• Annual subscriptions: Full refund within 30 days of purchase, pro-rata refund within 90 days
• Monthly subscriptions: Refund for current month if service is substantially unavailable
• No refund for: Feature usage, data storage, or third-party integration costs
• **Onboarding / setup / implementation fees and any third-party pass-through charges (e.g. SMS, payment-gateway, WhatsApp) are non-refundable.**

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
  LegalSection(
    title: 'Taxes (GST / OIDAR)',
    icon: Icons.receipt_long_outlined,
    content: '''• MicroFlow Pro subscription fees are inclusive of applicable **GST (currently 18%)** charged under the OIDAR (Online Information and Database Access or Retrieval) services framework for SaaS supplied from India.
• Approved refunds will reflect the taxable value net of GST already remitted to tax authorities, unless the entire invoice is cancelled within the same tax period (in which case GST is reversed in full).
• Tax invoices are issued electronically on payment and can be downloaded from Billing settings. For GST queries, contact [MICROFLOW_BILLING_EMAIL].''',
  ),
];

/// ===========================================================================
/// NEW: FAIR COLLECTION PRACTICES — RBI Digital Lending Guidelines
/// (DRAFT FOR LAWYER REVIEW — recommend adding to legal_content.dart
///  and surfacing in legal_policies_page.dart)
/// ===========================================================================
const kCollectionPracticesSections = [
  LegalSection(
    title: 'Fair Recovery Conduct',
    icon: Icons.handshake_outlined,
    content: '''MicroFlow is used by RBI-registered NBFCs/MFIs to manage collections. All recovery activity conducted through this platform follows the **RBI Master Direction on Digital Lending (2022)** and fair-practice norms:

• **No harassment:** Recovery agents must not use abusive, threatening, or intimidatory language or behaviour toward any borrower or their family.
• **Calling hours:** Borrowers are contacted only between **7:00 AM and 9:00 PM** local time.
• **Visits:** A maximum of **one field visit per borrower per day**, and only during permitted hours, with GPS-verified check-in/out.
• **Transparency:** All communication is logged and traceable within the platform.
• **Escalation:** Any complaint of agent misconduct may be raised with the NBFC's Grievance Redressal Officer or, for MicroFlow platform concerns, our GRO (see Privacy Policy).''',
  ),
  LegalSection(
    title: 'Logged & Accountable Actions',
    icon: Icons.history_rounded,
    content: '''To ensure accountability and protect borrowers:

• Every call attempt, SMS/WhatsApp notification, and field visit is **automatically logged** with timestamp, agent identity, and outcome.
• GPS coordinates captured during visits are recorded solely for field-verification and audit, never for surveillance beyond permitted recovery activity.
• Borrowers may request a record of recovery interactions concerning them through their lending institution.

MicroFlow provides the tooling; the lending NBFC/MFI remains responsible for the conduct of its recovery process in compliance with RBI guidelines.''',
  ),
];
```

---

## 4. Specific Change List (what to add / modify)

| # | Location | Action | Detail |
|---|----------|---------|--------|
| 1 | `legal_content.dart` → `kPrivacyPolicySections` | **ADD** section | "Our Role: Data Fiduciary & Data Processor" (fiduciary vs processor split) |
| 2 | `kPrivacyPolicySections` | **ADD** section | "Consent & Borrower Data Collection" (explicit consent, withdrawal, no children) |
| 3 | `kPrivacyPolicySections` | **ADD** section | "Data Localisation & Storage Location" (India servers, Supabase region) |
| 4 | `kPrivacyPolicySections` → "Data Retention" | **MODIFY** | Rename to "Data Retention & Erasure"; add erasure SLA + lawful-retention carve-out |
| 5 | `kPrivacyPolicySections` → "Your Rights" | **MODIFY** | Align to DPDP: add nomination, withdraw consent, complaint to Data Protection Board |
| 6 | `kPrivacyPolicySections` | **ADD** section | "Breach Notification" (72h Board notice, user notice, processor→fiduciary) |
| 7 | `kPrivacyPolicySections` | **ADD** section | "Grievance Redressal & Data Protection Officers" (GRO + DPO placeholders, 30-day SLA) |
| 8 | `kTermsOfServiceSections` | **ADD** section | "Technology Platform — Not an NBFC" (key liability disclaimer) |
| 9 | `kTermsOfServiceSections` → "Financial Disclaimers" | **MODIFY** | Tighten: explicitly "does NOT lend/disburse/collect"; credit decisions are NBFC's |
| 10 | `kTermsOfServiceSections` | **ADD** section | "Governing Law & Jurisdiction" (India, named city courts) |
| 11 | `kTermsOfServiceSections` → "Limitation of Liability" | **MODIFY** | Add "without prejudice to liability that cannot be excluded under Indian law" |
| 12 | `kDataProcessingSections` | **ADD/MODIFY** | Add "Parties & Roles", "Sub-Processing & Data Location", "Security, Breach & Audit"; rewrite "Legal Basis" to lead with **Consent** |
| 13 | `kRefundPolicySections` | **MODIFY** | Add non-refundable onboarding/3rd-party fees line |
| 14 | `kRefundPolicySections` | **ADD** section | "Taxes (GST / OIDAR)" — 18% note, GST-inclusive refunds, invoice source |
| 15 | `legal_content.dart` | **ADD** constant | `kCollectionPracticesSections` (Fair Recovery Conduct + Logged & Accountable Actions) |
| 16 | `legal_policies_page.dart` | **MODIFY** | Render the new `kCollectionPracticesSections` as a 5th ExpansionTile (title "Fair Collection Practices", icon `Icons.handshake_outlined`, color `Colors.green`) |
| 17 | `searchable_settings.dart` | **MODIFY** | Add `keywords` entries ('nbfc', 'dpdp', 'gst', 'consent', 'grievance', 'collection', 'recovery', 'data protection') to `legal_policies` setting so users can find the new content |
| 18 | `security_compliance_page.dart` | **OPTIONAL ADD** | Add a tappable card "Grievance & Data Protection Officers" linking to the GRO/DPO contact block, or surface the legal_policies route |

**Placeholders to fill before publish (Sayan / legal):**
`[MICROFLOW_LEGAL_ENTITY]`, `[SUPABASE_REGION]`, `[GRO_NAME]`, `[GRO_EMAIL]`, `[DPO_NAME]`, `[DPO_EMAIL]`, `[MICROFLOW_REGISTRED_OFFICE_CITY]`, `[MICROFLOW_BILLING_EMAIL]`.
