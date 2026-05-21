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
}
