// lib/core/constants/sms_templates.dart
//
// TRAI/DLT-compliant SMS templates for MicroFlow Finance (MFIFIN).
// All templates use {placeholder} syntax for data-driven filling.
// Promotional templates include mandatory STOP opt-out per TRAI guidelines.
//
// Character budget: ≤ 160 chars (single GSM-7 segment) where possible.

/// Centralised SMS template strings for every transactional and promotional
/// message sent by the app.
class SmsTemplates {
  SmsTemplates._();

  // ──────────────────────────────────────────────────
  //  EMI Reminders
  // ──────────────────────────────────────────────────

  /// 3 days before due date.
  static const emiReminder3Days =
      'MFIFIN: Hi {name}, your EMI of ₹{amount} for loan {loan_id} '
      'is due on {date}. Pay on time to avoid late fees. '
      '- MFIFIN';

  /// Due today.
  static const emiReminderDueToday =
      'MFIFIN: Hi {name}, your EMI of ₹{amount} for loan {loan_id} '
      'is due TODAY. Please pay ₹{amount} before end of day. '
      '- MFIFIN';

  /// 1 day overdue.
  static const emiReminderOverdue =
      'MFIFIN: Hi {name}, your EMI of ₹{amount} for loan {loan_id} '
      'was due on {date}. '
      'Clear dues now to avoid late fees. - MFIFIN';

  /// Overdue with balance shown.
  static const emiReminderOverdueWithBalance =
      'MFIFIN: Hi {name}, your EMI of ₹{amount} for loan {loan_id} '
      'was due on {date}. Outstanding: ₹{balance}. '
      'Clear dues now to avoid late fees. - MFIFIN';

  /// 7+ days overdue with penalty mention.
  static const escalationOverdue =
      'MFIFIN: URGENT {name}, loan {loan_id} is {days} days overdue. '
      'EMI ₹{amount} + penalty ₹{penalty_amount} due. '
      'Pay ₹{total} by {deadline} to avoid further action. - MFIFIN';

  // ──────────────────────────────────────────────────
  //  Payment Receipts — visual card format (≈4 segments).
  //  Footer uses {org_name} so orgs are white-labelled automatically.
  // ──────────────────────────────────────────────────

  /// Standard EMI payment receipt.
  static const emiPaymentReceived =
      'Hi {name}\n'
      'Payment Received\n'
      '─────────────\n'
      'Amount: {amount}\n'
      'Loan: {loan_id}\n'
      'Outstanding: {balance}\n'
      'Collected by: {collector}\n'
      'Date: {date}\n'
      '─────────────\n'
      'Thank you for your payment!\n'
      '{org_name}';

  /// Full loan closure congratulations.
  static const loanClosedReceipt =
      'Hi {name}\n'
      'Loan Closed \u2705\n'
      '─────────────\n'
      'Loan: {loan_id}\n'
      'Final Amount Paid: {total}\n'
      'Closed on: {date}\n'
      'Thank you for banking with us.\n'
      '─────────────\n'
      '{org_name}';

  /// Partial payment acknowledgment.
  static const partialPaymentReceipt =
      'Hi {name}\n'
      'Partial Payment Received\n'
      '─────────────\n'
      'Amount: {amount}\n'
      'Loan: {loan_id}\n'
      'Outstanding: {balance}\n'
      'Collected by: {collector}\n'
      'Date: {date}\n'
      '─────────────\n'
      'Pay full {total} by {next_due_date} to avoid penalty.\n'
      '{org_name}';

  // ──────────────────────────────────────────────────
  //  Savings Receipts
  // ──────────────────────────────────────────────────

  /// Savings deposit receipt.
  static const savingsDepositReceipt =
      'Hi {name}\n'
      'Savings Deposit Received\n'
      '─────────────\n'
      'Amount: {amount}\n'
      'Plan: {plan}\n'
      'Balance: {balance}\n'
      'Collected by: {collector}\n'
      'Date: {date}\n'
      '─────────────\n'
      'Thank you for saving with us!\n'
      '{org_name}';

  // ──────────────────────────────────────────────────
  //  Loan Disbursal
  // ──────────────────────────────────────────────────

  /// Loan approved and disbursed.
  static const loanDisbursed =
      'MFIFIN: Congrats {name}! Loan {loan_id} of ₹{amount} '
      'disbursed to A/c {account_no}. Rate: {rate}% p.a. '
      'First EMI: ₹{emi} due on {date}. - MicroFlow Finance';

  /// Loan application received / under review.
  static const loanApplicationReceived =
      'MFIFIN: Hi {name}, your loan application {app_id} '
      'for ₹{amount} is under review. We will update you in '
      '2-3 business days. - MicroFlow Finance';

  /// Loan rejected.
  static const loanRejected =
      'MFIFIN: Hi {name}, loan application {app_id} for ₹{amount} '
      'could not be approved at this time. '
      'Contact {phone} for details. - MicroFlow Finance';

  // ──────────────────────────────────────────────────
  //  KYC & Account
  // ──────────────────────────────────────────────────

  /// Pending KYC reminder.
  static const kycReminder =
      'MFIFIN: Hi {name}, your KYC is pending. '
      'Submit Aadhaar/PAN at your nearest branch or via the app '
      'by {deadline}. - MicroFlow Finance';

  /// KYC approved / verified.
  static const kycApproved =
      'MFIFIN: Hi {name}, your KYC has been verified. '
      'You can now access all services. '
      'A/c: {account_no}. - MFIFIN';

  /// Welcome / account activation.
  static const accountActivation =
      'MFIFIN: Welcome {name}! Your account {account_no} is active. '
      'Member ID: {ref_id}. '
      'Download the app: {phone}. - MicroFlow Finance';

  // ──────────────────────────────────────────────────
  //  Promotional  (TRAI: must include STOP opt-out)
  // ──────────────────────────────────────────────────

  /// Pre-approved top-up loan offer.
  static const newLoanOffer =
      'MFIFIN: {name}, you are pre-approved for a top-up loan '
      'of ₹{limit} at {rate}% p.a. Apply now in the app! '
      'Reply STOP to opt out. - MicroFlow Finance';

  /// Refer-a-friend bonus.
  static const referralOffer =
      'MFIFIN: Refer a friend to MicroFlow Finance and earn '
      '₹{bonus} on their first loan disbursement! '
      'Share code: {code}. Reply STOP to opt out. - MFIFIN';

  /// Festival / seasonal discount.
  static const festivalOffer =
      'MFIFIN: {festival} special! Get {discount}% off processing '
      'fee on new loans up to ₹{limit}. '
      'Offer valid till {deadline}. '
      'Reply STOP to opt out. - MicroFlow Finance';

  // ──────────────────────────────────────────────────
  //  Field Agent
  // ──────────────────────────────────────────────────

  /// Alert to agent about a due collection.
  static const agentCollectionAlert =
      'MFIFIN: {name} has EMI ₹{amount} due today (loan {loan_id}). '
      'Area: {area}. Collect and confirm in app. - MFIFIN';

  /// Confirmation sent to member after agent collects.
  static const collectionConfirmationToMember =
      'MFIFIN: {agent_name} collected ₹{amount} for loan {loan_id}. '
      'Txn: {txn_id}. Balance: ₹{balance}. '
      'Thank you! - MicroFlow Finance';
}

/// Utility to fill `{placeholder}` tokens in an SMS template string.
///
/// ```dart
/// final msg = SmsTemplateHelper.fill(
///   SmsTemplates.emiPaymentReceived,
///   {'amount': '2500', 'loan_id': 'L-1042', ...},
/// );
/// ```
class SmsTemplateHelper {
  SmsTemplateHelper._();

  /// Replaces every `{key}` in [template] with the corresponding value
  /// from [params]. Keys not present in [params] are left as-is so that
  /// missing-data bugs are visible in the output rather than silently dropped.
  static String fill(String template, Map<String, String> params) {
    var result = template;
    for (final entry in params.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }
}
