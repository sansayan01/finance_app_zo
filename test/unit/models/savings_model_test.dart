import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/features/savings/data/models/savings_model.dart';

void main() {
  group('SavingsModel', () {
    test('creates instance with required fields', () {
      final now = DateTime.now();
      final maturity = now.add(const Duration(days: 365));
      final savings = SavingsModel(
        id: 'sav-123',
        memberId: 'member-456',
        memberName: 'John Doe',
        planName: 'Gold Savings',
        targetAmount: 100000,
        currentAmount: 25000,
        monthlyDeposit: 2000,
        interestRate: 6.5,
        maturityDate: maturity,
        createdAt: now,
        status: 'active',
      );

      expect(savings.id, 'sav-123');
      expect(savings.memberId, 'member-456');
      expect(savings.memberName, 'John Doe');
      expect(savings.planName, 'Gold Savings');
      expect(savings.targetAmount, 100000);
      expect(savings.currentAmount, 25000);
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'sav-123',
        'member_id': 'member-456',
        'member_name': 'Jane Doe',
        'plan_name': 'Silver Plan',
        'target_amount': 50000.0,
        'current_amount': 15000.0,
        'monthly_deposit': 1500.0,
        'interest_rate': 5.5,
        'maturity_date': '2025-06-01T00:00:00.000Z',
        'created_at': '2024-01-01T10:00:00.000Z',
        'status': 'active',
      };

      final savings = SavingsModel.fromJson(json);

      expect(savings.id, 'sav-123');
      expect(savings.memberId, 'member-456');
      expect(savings.memberName, 'Jane Doe');
      expect(savings.planName, 'Silver Plan');
      expect(savings.targetAmount, 50000.0);
      expect(savings.currentAmount, 15000.0);
      expect(savings.monthlyDeposit, 1500.0);
      expect(savings.interestRate, 5.5);
      expect(savings.status, 'active');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'sav-123',
        'member_id': 'member-456',
        'target_amount': 50000,
        'current_amount': 15000,
        'maturity_date': '2025-06-01T00:00:00.000Z',
        'created_at': '2024-01-01T10:00:00.000Z',
      };

      final savings = SavingsModel.fromJson(json);

      expect(savings.memberName, '');
      expect(savings.planName, '');
      expect(savings.monthlyDeposit, 0.0);
      expect(savings.interestRate, 0.0);
      expect(savings.status, 'active');
    });

    test('fromJson handles matured status', () {
      final json = {
        'id': 'sav-123',
        'member_id': 'member-456',
        'target_amount': 100000,
        'current_amount': 100000,
        'maturity_date': '2025-06-01T00:00:00.000Z',
        'created_at': '2024-01-01T10:00:00.000Z',
        'status': 'matured',
      };

      final savings = SavingsModel.fromJson(json);

      expect(savings.status, 'matured');
    });

    test('toJson serializes correctly', () {
      final now = DateTime(2024, 1, 1, 10, 0);
      final maturity = DateTime(2025, 6, 1);
      final savings = SavingsModel(
        id: 'sav-123',
        memberId: 'member-456',
        memberName: 'Test User',
        planName: 'Test Plan',
        targetAmount: 50000,
        currentAmount: 15000,
        monthlyDeposit: 1500,
        interestRate: 5.5,
        maturityDate: maturity,
        createdAt: now,
        status: 'active',
      );

      final json = savings.toJson();

      expect(json['id'], 'sav-123');
      expect(json['member_id'], 'member-456');
      expect(json['member_name'], 'Test User');
      expect(json['plan_name'], 'Test Plan');
      expect(json['target_amount'], 50000);
      expect(json['current_amount'], 15000);
      expect(json['status'], 'active');
    });
  });

  group('SavingsSummary', () {
    test('fromJson parses correctly', () {
      final json = {
        'total_savings': 5000000.0,
        'active_accounts': 150,
        'average_balance': 33333.33,
        'interest_earned': 250000.0,
      };

      final summary = SavingsSummary.fromJson(json);

      expect(summary.totalSavings, 5000000.0);
      expect(summary.activeAccounts, 150);
      expect(summary.averageBalance, 33333.33);
      expect(summary.interestEarned, 250000.0);
    });

    test('fromJson handles null values with defaults', () {
      final json = <String, dynamic>{};

      final summary = SavingsSummary.fromJson(json);

      expect(summary.totalSavings, 0.0);
      expect(summary.activeAccounts, 0);
      expect(summary.averageBalance, 0.0);
      expect(summary.interestEarned, 0.0);
    });
  });
}
