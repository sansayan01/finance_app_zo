import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/features/loans/data/models/loan_model.dart';
import 'package:microflow_pro/core/constants/enums.dart';

void main() {
  group('LoanModel', () {
    test('creates instance with required fields', () {
      final now = DateTime.now();
      final loan = LoanModel(
        id: 'loan-123',
        customerId: 'cust-456',
        loanNumber: 'LN2024001',
        amount: 50000,
        interestRate: 12.0,
        tenureMonths: 12,
        emiAmount: 4433.33,
        totalInterest: 3200,
        totalRepayable: 53200,
        outstandingBalance: 53200,
        interestType: InterestType.flat,
        status: LoanStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      expect(loan.id, 'loan-123');
      expect(loan.customerId, 'cust-456');
      expect(loan.loanNumber, 'LN2024001');
      expect(loan.amount, 50000);
      expect(loan.interestRate, 12.0);
      expect(loan.tenureMonths, 12);
    });

    test('fromJson parses basic loan data', () {
      final json = {
        'id': 'loan-123',
        'customer_id': 'cust-456',
        'loan_number': 'LN2024001',
        'amount': 100000.0,
        'interest_rate': 15.5,
        'tenure_months': 24,
        'emi_amount': 4850.0,
        'total_interest': 16400,
        'total_repayable': 116400,
        'outstanding_balance': 116400,
        'interest_type': 'reducing',
        'status': 'active',
        'purpose': 'Business',
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-01T10:00:00Z',
      };

      final loan = LoanModel.fromJson(json);

      expect(loan.id, 'loan-123');
      expect(loan.customerId, 'cust-456');
      expect(loan.amount, 100000.0);
      expect(loan.interestRate, 15.5);
      expect(loan.interestType, InterestType.reducing);
      expect(loan.status, LoanStatus.active);
      expect(loan.purpose, 'Business');
    });

    test('fromJson parses joined customer data', () {
      final json = {
        'id': 'loan-123',
        'customer_id': 'cust-456',
        'amount': 50000.0,
        'interest_rate': 12.0,
        'tenure_months': 12,
        'emi_amount': 4433.0,
        'total_interest': 3200,
        'total_repayable': 53200,
        'outstanding_balance': 53200,
        'interest_type': 'flat',
        'status': 'active',
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-01T10:00:00Z',
        'customers': {
          'full_name': 'John Doe',
          'phone': '+919999999999',
        },
      };

      final loan = LoanModel.fromJson(json);

      expect(loan.customerName, 'John Doe');
      expect(loan.customerPhone, '+919999999999');
    });

    test('fromJson handles staff join data', () {
      final json = {
        'id': 'loan-123',
        'customer_id': 'cust-456',
        'amount': 50000.0,
        'interest_rate': 12.0,
        'tenure_months': 12,
        'emi_amount': 4433.0,
        'total_interest': 3200,
        'total_repayable': 53200,
        'outstanding_balance': 53200,
        'interest_type': 'flat',
        'status': 'active',
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-01T10:00:00Z',
        'staff': {
          'full_name': 'Agent Smith',
        },
      };

      final loan = LoanModel.fromJson(json);

      expect(loan.staffName, 'Agent Smith');
    });

    test('fromJson handles alternative field names', () {
      final json = {
        'id': 'loan-123',
        'borrower_id': 'cust-456',
        'principal_amount': 75000.0,
        'interest_rate': 14.0,
        'tenure_months': 18,
        'estimated_installment': 4600.0,
        'total_exposure': 82800,
        'interest_type': 'flat',
        'status': 'pending',
        'first_installment_date': '2024-02-01',
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-01T10:00:00Z',
      };

      final loan = LoanModel.fromJson(json);

      expect(loan.customerId, 'cust-456');
      expect(loan.amount, 75000.0);
      expect(loan.emiAmount, 4600.0);
      expect(loan.status, LoanStatus.pending);
    });

    test('fromJson handles defaulted status mapping', () {
      final json = {
        'id': 'loan-123',
        'customer_id': 'cust-456',
        'amount': 50000.0,
        'interest_rate': 12.0,
        'tenure_months': 12,
        'emi_amount': 4433.0,
        'total_interest': 3200,
        'total_repayable': 53200,
        'outstanding_balance': 53200,
        'interest_type': 'flat',
        'status': 'defaulted',
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-01T10:00:00Z',
      };

      final loan = LoanModel.fromJson(json);

      expect(loan.status, LoanStatus.defaultStatus);
    });

    test('toJson serializes correctly', () {
      final now = DateTime(2024, 1, 1, 10, 0);
      final loan = LoanModel(
        id: 'loan-123',
        customerId: 'cust-456',
        loanNumber: 'LN2024001',
        amount: 50000,
        interestRate: 12.0,
        tenureMonths: 12,
        emiAmount: 4433.33,
        totalInterest: 3200,
        totalRepayable: 53200,
        outstandingBalance: 40000,
        interestType: InterestType.flat,
        status: LoanStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final json = loan.toJson();

      expect(json['id'], 'loan-123');
      expect(json['customer_id'], 'cust-456');
      expect(json['loan_number'], 'LN2024001');
      expect(json['amount'], 50000);
      expect(json['interest_type'], 'flat');
      expect(json['status'], 'active');
    });
  });

  group('LoanSummary', () {
    test('fromJson parses correctly', () {
      final json = {
        'total_loans': 150,
        'active_loans': 120,
        'default_loans': 5,
        'total_outstanding': 5000000.0,
        'total_disbursed': 7500000.0,
        'total_collected': 2500000.0,
        'overdue_amount': 150000.0,
        'par_percentage': 3.0,
      };

      final summary = LoanSummary.fromJson(json);

      expect(summary.totalLoans, 150);
      expect(summary.activeLoans, 120);
      expect(summary.defaultLoans, 5);
      expect(summary.totalOutstanding, 5000000.0);
      expect(summary.totalDisbursed, 7500000.0);
      expect(summary.totalCollected, 2500000.0);
      expect(summary.overdueAmount, 150000.0);
      expect(summary.parPercentage, 3.0);
    });

    test('fromJson handles null values with defaults', () {
      final json = <String, dynamic>{};

      final summary = LoanSummary.fromJson(json);

      expect(summary.totalLoans, 0);
      expect(summary.activeLoans, 0);
      expect(summary.totalOutstanding, 0.0);
    });
  });
}
