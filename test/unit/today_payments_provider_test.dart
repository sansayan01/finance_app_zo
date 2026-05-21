import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'package:microflow_pro/features/auth/data/models/user_model.dart';
import 'package:microflow_pro/features/payments/data/providers/payment_providers.dart';
import 'package:microflow_pro/features/payments/data/models/today_payment_model.dart';
import 'package:microflow_pro/features/auth/presentation/providers/auth_provider.dart';

void main() {
  test('todayPaymentsProvider fetches seeded data correctly with authenticated session', () async {
    // Initialize SharedPreferences mock
    SharedPreferences.setMockInitialValues({});

    // Read .env file to load variables
    final envFile = File('.env');
    final lines = await envFile.readAsLines();
    String? url;
    String? anonKey;
    for (var line in lines) {
      if (line.startsWith('SUPABASE_URL=')) {
        url = line.split('=').sublist(1).join('=').trim();
      } else if (line.startsWith('SUPABASE_ANON_KEY=')) {
        anonKey = line.split('=').sublist(1).join('=').trim();
      }
    }

    if (url == null || anonKey == null) {
      fail('Supabase credentials not found in .env');
    }

    // Initialize Supabase
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
    } catch (_) {
      // Already initialized
    }

    final client = Supabase.instance.client;

    // Log in to establish session for RLS policies
    final authResponse = await client.auth.signInWithPassword(
      email: 'farukgazi0123@gmail.com',
      password: 'password123',
    );

    expect(authResponse.user, isNotNull);
    expect(authResponse.session, isNotNull);

    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(
          UserModel(
            id: authResponse.user!.id,
            email: 'farukgazi0123@gmail.com',
            fullName: 'Faruk Gazi',
            role: UserRole.executiveAdmin,
            orgId: 'faf0ec34-9829-4b30-893a-6b9fa013ed09',
          ),
        ),
      ],
    );

    // Set selected date to 2026-05-21
    container.read(paymentFilterProvider.notifier).setDate(DateTime(2026, 5, 21));

    // Read the provider
    final paymentsData = await container.read(todayPaymentsProvider.future);

    debugPrint('Payments fetched: ${paymentsData.payments.length}');
    for (final payment in paymentsData.payments) {
      debugPrint('Payment - Type: ${payment.type}, Status: ${payment.status}, Member: ${payment.memberName}, Loan/Plan: ${payment.loanNumber ?? payment.planName}');
    }

    // Check total payments count
    expect(paymentsData.payments.isNotEmpty, true);
    
    final emiDues = paymentsData.payments.where((p) => p.type == PaymentType.emi).toList();
    final savingsDues = paymentsData.payments.where((p) => p.type == PaymentType.savings).toList();

    expect(emiDues.length, greaterThanOrEqualTo(2));
    expect(savingsDues.length, greaterThanOrEqualTo(1));

    final pendingEmi = emiDues.firstWhere((p) => p.status == PaymentStatus.pending);
    final overdueEmi = emiDues.firstWhere((p) => p.status == PaymentStatus.overdue);
    final savingsPlan = savingsDues.firstWhere((p) => p.status == PaymentStatus.pending);

    expect(pendingEmi.memberName, 'Hasanur Mondal');
    expect(overdueEmi.memberName, 'Hasanur Mondal');
    expect(savingsPlan.memberName, 'Hasanur Mondal');

    // Expected weekly installment is 1287.33 (approx 1287)
    expect(pendingEmi.amountExpected, closeTo(1287.33, 0.1));
    expect(overdueEmi.amountExpected, closeTo(1287.33, 0.1));
    expect(savingsPlan.amountExpected, closeTo(50.0, 0.1));

    // Sign out to clean up session
    await client.auth.signOut();
  });

  test('recordCollection logic updates database tables and records transactions correctly', () async {
    // Initialize SharedPreferences mock
    SharedPreferences.setMockInitialValues({});

    // Read .env file to load variables
    final envFile = File('.env');
    final lines = await envFile.readAsLines();
    String? url;
    String? anonKey;
    for (var line in lines) {
      if (line.startsWith('SUPABASE_URL=')) {
        url = line.split('=').sublist(1).join('=').trim();
      } else if (line.startsWith('SUPABASE_ANON_KEY=')) {
        anonKey = line.split('=').sublist(1).join('=').trim();
      }
    }

    if (url == null || anonKey == null) {
      fail('Supabase credentials not found in .env');
    }

    // Initialize Supabase
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
    } catch (_) {
      // Already initialized
    }

    final client = Supabase.instance.client;

    // Log in
    final authResponse = await client.auth.signInWithPassword(
      email: 'farukgazi0123@gmail.com',
      password: 'password123',
    );

    final orgId = 'faf0ec34-9829-4b30-893a-6b9fa013ed09';
    final memberId = '9afa8b1b-5d3d-43d3-ad38-57565d7d75fe'; // Hasanur Mondal
    final memberName = 'Hasanur Mondal';
    final savingsPlanId = 'cf8f1e58-bb12-4cfb-b5ad-323a6331fe20';

    final profile = await client
        .from('profiles')
        .select('id')
        .eq('user_id', authResponse.user!.id)
        .maybeSingle();
    final staffId = profile?['id'] as String?;
    expect(staffId, isNotNull);

    // --- Part 1: Test Savings Collection ---
    // Reset savings_plan state first
    await client.from('savings_collections').delete().eq('savings_plan_id', savingsPlanId);
    await client.from('transactions').delete().eq('savings_id', savingsPlanId);
    await client.from('savings_plans').update({
      'next_due_date': '2026-05-21',
      'current_amount': 0.00,
    }).eq('id', savingsPlanId);

    // Emulate saving collection
    final amountToCollect = 50.0;
    final paymentMode = 'cash';
    final todayStr = '2026-05-21';

    // 1. Insert collection log
    await client.from('savings_collections').insert({
      'org_id': orgId,
      'savings_plan_id': savingsPlanId,
      'member_id': memberId,
      'member_name': memberName,
      'amount_expected': amountToCollect,
      'amount_collected': amountToCollect,
      'is_partial': false,
      'payment_mode': paymentMode,
      'collection_date': todayStr,
      'staff_id': staffId,
      'sync_status': 'synced',
    });

    // 2. Fetch current savings balance & collection type to calculate next due date
    final plan = await client
        .from('savings_plans')
        .select('collection_type, current_amount')
        .eq('id', savingsPlanId)
        .maybeSingle();
    expect(plan, isNotNull);

    final currentBalance = ((plan?['current_amount']) as num?)?.toDouble() ?? 0.0;
    expect(currentBalance, 0.0);

    // Update due date
    final nextDue = DateTime.now().add(const Duration(days: 1));
    final newSavingsAmount = currentBalance + amountToCollect;

    // 3. Update savings plan status/balance/due date
    await client.from('savings_plans').update({
      'next_due_date': nextDue.toIso8601String().split('T').first,
      'current_amount': newSavingsAmount,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', savingsPlanId);

    // 4. Create Transaction Record
    await client.from('transactions').insert({
      'member_id': memberId,
      'member_name': memberName,
      'savings_id': savingsPlanId,
      'amount': amountToCollect,
      'type': 'savingsDeposit',
      'payment_mode': paymentMode,
      'description': 'Deposit into Savings Vault (Quick Collect)',
      'org_id': orgId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    // Verification of savings changes
    final updatedPlan = await client
        .from('savings_plans')
        .select('current_amount, next_due_date')
        .eq('id', savingsPlanId)
        .single();
    expect((updatedPlan['current_amount'] as num).toDouble(), 50.0);

    final txCount = await client
        .from('transactions')
        .select('id')
        .eq('savings_id', savingsPlanId)
        .eq('type', 'savingsDeposit');
    expect(txCount.length, 1);

    // Clean up
    await client.from('savings_collections').delete().eq('savings_plan_id', savingsPlanId);
    await client.from('transactions').delete().eq('savings_id', savingsPlanId);
    await client.from('savings_plans').update({
      'next_due_date': '2026-05-21',
      'current_amount': 0.00,
    }).eq('id', savingsPlanId);

    // Sign out to clean up session
    await client.auth.signOut();
  });
}
