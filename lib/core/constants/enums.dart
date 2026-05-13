enum UserRole {
  superAdmin,      // Platform super admin - manages all organizations
  executiveAdmin,  // Organization admin - manages their organization
  admin,           // Branch admin - can create users for their branch
  manager,         // Branch manager - manages specific branch
  fieldStaff,      // Field staff - general operations
  collectionAgent, // Collection agent - collects payments from customers
  customer,        // Customer - end user with loans/savings
  retailMember,    // Legacy alias for customer
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
