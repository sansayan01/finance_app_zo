enum UserRole {
  superAdmin,      // Platform super admin - manages all organizations
  executiveAdmin,  // Organization admin - manages their organization, creates branches
  manager,         // Branch admin - manages their branch, creates staff/customers
  collectionAgent, // Field staff - collects payments from customers
  customer,        // End user - has loans/savings
}

enum LoanStatus {
  draft,
  pending,
  approved,
  active,
  closed,
  rejected,
  defaultStatus,
  restructured,
}

enum InterestType {
  flat,
  reducing,
}

enum EMIStatus {
  upcoming,
  paid,
  overdue,
  defaulted,
  pendingPayment,
}

enum SavingsFrequency {
  daily,
  weekly,
  monthly,
}

enum SavingsStatus {
  active,
  matured,
  withdrawn,
  cancelled,
}

enum TransactionType {
  loanDisbursement,
  emiPayment,
  savingsDeposit,
  savingsWithdrawal,
  penalty,
  staffCashDeposit,
  other,
}

enum PaymentMode {
  cash,
  upi,
  bankTransfer,
  cheque,
  card,
}

enum CustomerStatus {
  active,
  inactive,
  blacklisted,
}

enum CollectionFrequency {
  daily,
  weekly,
  monthly,
  yearly,
}

enum KYCStatus {
  pending,
  verified,
  rejected,
  notSubmitted,
}

enum BranchStatus {
  active,
  inactive,
  closed,
}
