# UPI Payment Feature — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let customers pay loan EMIs and savings installments via UPI deep links, with staff/admin confirmation.

**Architecture:** Customer taps "Pay via UPI" → QR code + UPI intent opens native UPI app → customer pays → taps "I've Paid" → pending payment request created → staff/admin confirms → standard collection record created via existing trigger.

**Tech Stack:** Flutter, Dart, Riverpod, Supabase, url_launcher, qr_flutter

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `supabase/migrations/20260621000001_upi_payment_requests.sql` | Creates `upi_payment_requests` table + RLS policies |
| `lib/features/payments/data/models/upi_payment_request_model.dart` | Data class for `upi_payment_requests` rows |
| `lib/features/payments/data/repositories/upi_payment_repository.dart` | Supabase queries: create, list, confirm, reject |
| `lib/features/payments/data/providers/upi_providers.dart` | Riverpod providers for UPI payment requests |
| `lib/features/payments/data/services/upi_service.dart` | UPI intent URI generation, VPA config read/write |
| `lib/features/payments/presentation/widgets/upi_payment_sheet.dart` | Customer-facing bottom sheet: QR + "Open UPI" + "I've Paid" |
| `lib/features/payments/presentation/widgets/upi_confirm_dialog.dart` | Staff confirm/reject dialog |
| `lib/features/payments/presentation/pages/upi_confirmations_page.dart` | Staff/admin/manager pending UPI payments list |
| `test/features/payments/data/services/upi_service_test.dart` | Unit tests for UPI service |
| `test/features/payments/data/repositories/upi_payment_repository_test.dart` | Unit tests for repository |

### Modified Files
| File | Change |
|------|--------|
| `lib/core/constants/enums.dart` | Add `UpiPaymentStatus` enum |
| `lib/features/settings/presentation/pages/organization_settings_page.dart` | Add Payment Configuration section |
| `lib/features/customer_portal/presentation/pages/customer_emi_schedule_page.dart` | Add "Pay via UPI" button per EMI |
| `lib/features/customer_portal/presentation/pages/customer_loan_detail_page.dart` | Add "Pay via UPI" action button |
| `lib/features/customer_portal/presentation/pages/customer_savings_detail_page.dart` | Add "Pay via UPI" button |
| `lib/features/staff/presentation/pages/staff_home_dashboard.dart` | Add "UPI Confirmations" quick action |
| `lib/features/settings/presentation/pages/integrations_settings_page.dart` | Mark UPI as implemented |
| `lib/core/routes/app_router.dart` | Add route for UPI confirmations page |

---

## Task 1: Database Migration — Create `upi_payment_requests` Table

**Files:**
- Create: `supabase/migrations/20260621000001_upi_payment_requests.sql`

**Interfaces:**
- Produces: `upi_payment_requests` table with RLS policies following existing `get_user_org_id()` / `get_user_role()` pattern

- [ ] **Step 1: Create migration file**

```sql
-- supabase/migrations/20260621000001_upi_payment_requests.sql

-- UPI Payment Requests: customer-initiated payments pending staff/admin confirmation
create table if not exists public.upi_payment_requests (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations(id) on delete cascade,
  customer_id     uuid not null references auth.users(id) on delete cascade,
  member_id       uuid references public.members(id),
  loan_id         uuid references public.loans(id),
  savings_plan_id uuid references public.savings_plans(id),
  emi_schedule_id uuid references public.emi_schedule(id),
  amount          numeric(12,2) not null check (amount > 0),
  upi_vpa         text not null,
  transaction_ref text,
  status          text not null default 'pending'
                  check (status in ('pending', 'confirmed', 'rejected')),
  confirmed_by    uuid references auth.users(id),
  confirmed_at    timestamptz,
  rejection_reason text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Indexes
create index if not exists upi_payment_requests_org_status_idx
  on public.upi_payment_requests (org_id, status);
create index if not exists upi_payment_requests_customer_idx
  on public.upi_payment_requests (customer_id, created_at desc);
create index if not exists upi_payment_requests_pending_idx
  on public.upi_payment_requests (org_id, status, created_at desc)
  where status = 'pending';

-- RLS
alter table public.upi_payment_requests enable row level security;

-- Customers can view their own requests
create policy upi_req_select_own on public.upi_payment_requests
  for select using (customer_id = auth.uid());

-- Org staff/admin/manager can view all org requests
create policy upi_req_select_org on public.upi_payment_requests
  for select using (
    org_id = public.get_user_org_id()
    and public.get_user_role() in ('executiveAdmin', 'manager', 'collectionAgent')
  );

-- Customers can insert their own requests
create policy upi_req_insert_own on public.upi_payment_requests
  for insert with check (customer_id = auth.uid());

-- Org staff/admin/manager can update (confirm/reject) org requests
create policy upi_req_update_org on public.upi_payment_requests
  for update using (
    org_id = public.get_user_org_id()
    and public.get_user_role() in ('executiveAdmin', 'manager', 'collectionAgent')
  );
```

- [ ] **Step 2: Commit migration**

```bash
git add supabase/migrations/20260621000001_upi_payment_requests.sql
git commit -m "feat(upi): add upi_payment_requests table migration"
```

---

## Task 2: UPI Payment Request Model

**Files:**
- Create: `lib/features/payments/data/models/upi_payment_request_model.dart`

**Interfaces:**
- Produces: `UpiPaymentRequest` class with `fromJson`, `toInsertMap`, `copyWith`

- [ ] **Step 1: Create the model file**

```dart
// lib/features/payments/data/models/upi_payment_request_model.dart

class UpiPaymentRequest {
  final String id;
  final String orgId;
  final String customerId;
  final String? memberId;
  final String? loanId;
  final String? savingsPlanId;
  final String? emiScheduleId;
  final double amount;
  final String upiVpa;
  final String? transactionRef;
  final String status; // 'pending', 'confirmed', 'rejected'
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UpiPaymentRequest({
    required this.id,
    required this.orgId,
    required this.customerId,
    this.memberId,
    this.loanId,
    this.savingsPlanId,
    this.emiScheduleId,
    required this.amount,
    required this.upiVpa,
    this.transactionRef,
    required this.status,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UpiPaymentRequest.fromJson(Map<String, dynamic> json) {
    return UpiPaymentRequest(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      memberId: json['member_id']?.toString(),
      loanId: json['loan_id']?.toString(),
      savingsPlanId: json['savings_plan_id']?.toString(),
      emiScheduleId: json['emi_schedule_id']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      upiVpa: json['upi_vpa']?.toString() ?? '',
      transactionRef: json['transaction_ref']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      confirmedBy: json['confirmed_by']?.toString(),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.tryParse(json['confirmed_at'].toString())
          : null,
      rejectionReason: json['rejection_reason']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'org_id': orgId,
      'customer_id': customerId,
      if (memberId != null) 'member_id': memberId,
      if (loanId != null) 'loan_id': loanId,
      if (savingsPlanId != null) 'savings_plan_id': savingsPlanId,
      if (emiScheduleId != null) 'emi_schedule_id': emiScheduleId,
      'amount': amount,
      'upi_vpa': upiVpa,
      if (transactionRef != null) 'transaction_ref': transactionRef,
      'status': status,
    };
  }

  UpiPaymentRequest copyWith({
    String? status,
    String? confirmedBy,
    DateTime? confirmedAt,
    String? rejectionReason,
    String? transactionRef,
  }) {
    return UpiPaymentRequest(
      id: id,
      orgId: orgId,
      customerId: customerId,
      memberId: memberId,
      loanId: loanId,
      savingsPlanId: savingsPlanId,
      emiScheduleId: emiScheduleId,
      amount: amount,
      upiVpa: upiVpa,
      transactionRef: transactionRef ?? this.transactionRef,
      status: status ?? this.status,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';
  bool get isLoanPayment => loanId != null;
  bool get isSavingsPayment => savingsPlanId != null;
}
```

- [ ] **Step 2: Run analyzer to verify no errors**

Run: `dart analyze lib/features/payments/data/models/upi_payment_request_model.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/payments/data/models/upi_payment_request_model.dart
git commit -m "feat(upi): add UpiPaymentRequest data model"
```

---

## Task 3: Add `UpiPaymentStatus` Enum

**Files:**
- Modify: `lib/core/constants/enums.dart`

**Interfaces:**
- Produces: `UpiPaymentStatus` enum used by providers and UI

- [ ] **Step 1: Add enum to enums.dart**

Add after the `PaymentMode` enum (around line 65):

```dart
enum UpiPaymentStatus {
  pending,
  confirmed,
  rejected,
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/constants/enums.dart
git commit -m "feat(upi): add UpiPaymentStatus enum"
```

---

## Task 4: UPI Service — Intent URI Generation + VPA Config

**Files:**
- Create: `lib/features/payments/data/services/upi_service.dart`
- Create: `test/features/payments/data/services/upi_service_test.dart`

**Interfaces:**
- Consumes: `SupabaseClient`, org ID from providers
- Produces: `UpiService` with `buildUpiUri`, `getOrgVpa`, `saveOrgVpa`, `hasPendingPayment`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/payments/data/services/upi_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/features/payments/data/services/upi_service.dart';

void main() {
  group('UpiService.buildUpiUri', () {
    test('builds correct UPI URI with all params', () {
      final uri = UpiService.buildUpiUri(
        vpa: 'merchant@upi',
        amount: 2500.00,
        merchantName: 'My Finance Org',
        transactionNote: 'Loan #123 — EMI #5',
      );
      expect(uri, contains('upi://pay?'));
      expect(uri, contains('pa=merchant%40upi'));
      expect(uri, contains('am=2500.00'));
      expect(uri, contains('pn=My+Finance+Org'));
      expect(uri, contains('cu=INR'));
    });

    test('builds correct UPI URI with integer amount', () {
      final uri = UpiService.buildUpiUri(
        vpa: 'test@upi',
        amount: 100,
        merchantName: 'Test',
        transactionNote: 'Savings #1',
      );
      expect(uri, contains('am=100.00'));
    });

    test('encodes special characters in transaction note', () {
      final uri = UpiService.buildUpiUri(
        vpa: 'test@upi',
        amount: 500,
        merchantName: 'Org',
        transactionNote: 'Loan#123-EMI#5',
      );
      // # is encoded as %23
      expect(uri, contains('tn=Loan%23123-EMI%235'));
    });

    test('validates VPA format contains @', () {
      expect(UpiService.isValidVpa('merchant@upi'), true);
      expect(UpiService.isValidVpa('user@bank'), true);
      expect(UpiService.isValidVpa('invalid-vpa'), false);
      expect(UpiService.isValidVpa(''), false);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/features/payments/data/services/upi_service_test.dart`
Expected: FAIL — `UpiService` class not found

- [ ] **Step 3: Implement the UPI service**

```dart
// lib/features/payments/data/services/upi_service.dart
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpiService {
  final SupabaseClient _client;
  final String _orgId;

  UpiService(this._client, this._orgId);

  /// Builds a UPI intent URI for the given payment details.
  static String buildUpiUri({
    required String vpa,
    required double amount,
    required String merchantName,
    required String transactionNote,
  }) {
    final params = {
      'pa': vpa,
      'am': amount.toStringAsFixed(2),
      'pn': merchantName,
      'tn': transactionNote,
      'cu': 'INR',
    };
    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'upi://pay?$queryString';
  }

  /// Basic VPA validation — must contain @
  static bool isValidVpa(String vpa) {
    return vpa.contains('@') && vpa.trim().isNotEmpty;
  }

  /// Reads the org's UPI config from organizations.settings JSONB.
  /// Returns null if not configured.
  Future<Map<String, dynamic>?> getOrgVpa() async {
    try {
      final data = await _client
          .from('organizations')
          .select('settings')
          .eq('id', _orgId)
          .maybeSingle();
      if (data == null) return null;
      final settings = data['settings'] as Map<String, dynamic>?;
      if (settings == null) return null;
      final payment = settings['payment'] as Map<String, dynamic>?;
      return payment;
    } catch (_) {
      return null;
    }
  }

  /// Saves UPI config to organizations.settings JSONB under the "payment" key.
  Future<void> saveOrgVpa({
    required String vpa,
    required String merchantName,
  }) async {
    // Read current settings, merge payment config
    final data = await _client
        .from('organizations')
        .select('settings')
        .eq('id', _orgId)
        .maybeSingle();
    final settings = (data?['settings'] as Map<String, dynamic>?) ?? {};
    final updated = Map<String, dynamic>.from(settings);
    updated['payment'] = {
      'upi_vpa': vpa,
      'merchant_name': merchantName,
    };
    await _client
        .from('organizations')
        .update({'settings': updated}).eq('id', _orgId);
  }

  /// Checks if a pending UPI payment request exists for the given installment.
  Future<bool> hasPendingPayment({
    String? emiScheduleId,
    String? savingsPlanId,
    String? customerId,
  }) async {
    var query = _client
        .from('upi_payment_requests')
        .select('id')
        .eq('org_id', _orgId)
        .eq('status', 'pending');

    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    }

    if (emiScheduleId != null) {
      query = query.eq('emi_schedule_id', emiScheduleId);
    } else if (savingsPlanId != null) {
      query = query.eq('savings_plan_id', savingsPlanId);
    } else {
      return false;
    }

    final data = await query.limit(1);
    return (data as List).isNotEmpty;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/features/payments/data/services/upi_service_test.dart`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/payments/data/services/upi_service.dart test/features/payments/data/services/upi_service_test.dart
git commit -m "feat(upi): add UPI service with intent URI generation and VPA config"
```

---

## Task 5: UPI Payment Repository

**Files:**
- Create: `lib/features/payments/data/repositories/upi_payment_repository.dart`

**Interfaces:**
- Consumes: `SupabaseClient`, org ID
- Produces: `UpiPaymentRepository` with `createRequest`, `getPendingRequests`, `getOrgRequests`, `confirmPayment`, `rejectPayment`, `checkExistingPending`

- [ ] **Step 1: Create the repository**

```dart
// lib/features/payments/data/repositories/upi_payment_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/upi_payment_request_model.dart';

class UpiPaymentRepository {
  final SupabaseClient _client;
  final String _orgId;

  UpiPaymentRepository(this._client, this._orgId);

  /// Creates a new pending UPI payment request.
  Future<UpiPaymentRequest> createRequest({
    required String customerId,
    String? memberId,
    String? loanId,
    String? savingsPlanId,
    String? emiScheduleId,
    required double amount,
    required String upiVpa,
  }) async {
    final data = await _client
        .from('upi_payment_requests')
        .insert({
          'org_id': _orgId,
          'customer_id': customerId,
          if (memberId != null) 'member_id': memberId,
          if (loanId != null) 'loan_id': loanId,
          if (savingsPlanId != null) 'savings_plan_id': savingsPlanId,
          if (emiScheduleId != null) 'emi_schedule_id': emiScheduleId,
          'amount': amount,
          'upi_vpa': upiVpa,
          'status': 'pending',
        })
        .select()
        .single();
    return UpiPaymentRequest.fromJson(data);
  }

  /// Checks if a pending payment already exists for this installment.
  Future<bool> checkExistingPending({
    String? emiScheduleId,
    String? savingsPlanId,
    required String customerId,
  }) async {
    var query = _client
        .from('upi_payment_requests')
        .select('id')
        .eq('org_id', _orgId)
        .eq('customer_id', customerId)
        .eq('status', 'pending');

    if (emiScheduleId != null) {
      query = query.eq('emi_schedule_id', emiScheduleId);
    } else if (savingsPlanId != null) {
      query = query.eq('savings_plan_id', savingsPlanId);
    } else {
      return false;
    }

    final data = await query.limit(1);
    return (data as List).isNotEmpty;
  }

  /// Gets pending UPI requests for the org (staff/admin/manager view).
  Future<List<UpiPaymentRequest>> getPendingRequests() async {
    final data = await _client
        .from('upi_payment_requests')
        .select()
        .eq('org_id', _orgId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => UpiPaymentRequest.fromJson(e))
        .toList();
  }

  /// Gets all UPI requests for the org with optional status filter.
  Future<List<UpiPaymentRequest>> getOrgRequests({String? status}) async {
    var query = _client
        .from('upi_payment_requests')
        .select()
        .eq('org_id', _orgId);
    if (status != null) {
      query = query.eq('status', status);
    }
    final data = await query.order('created_at', ascending: false).limit(100);
    return (data as List)
        .map((e) => UpiPaymentRequest.fromJson(e))
        .toList();
  }

  /// Gets UPI requests for a specific customer.
  Future<List<UpiPaymentRequest>> getCustomerRequests(String customerId) async {
    final data = await _client
        .from('upi_payment_requests')
        .select()
        .eq('org_id', _orgId)
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List)
        .map((e) => UpiPaymentRequest.fromJson(e))
        .toList();
  }

  /// Confirms a pending UPI payment request.
  Future<UpiPaymentRequest> confirmPayment({
    required String requestId,
    required String confirmedBy,
    String? transactionRef,
  }) async {
    final data = await _client
        .from('upi_payment_requests')
        .update({
          'status': 'confirmed',
          'confirmed_by': confirmedBy,
          'confirmed_at': DateTime.now().toIso8601String(),
          if (transactionRef != null) 'transaction_ref': transactionRef,
        })
        .eq('id', requestId)
        .eq('status', 'pending')
        .select()
        .single();
    return UpiPaymentRequest.fromJson(data);
  }

  /// Rejects a pending UPI payment request with a reason.
  Future<UpiPaymentRequest> rejectPayment({
    required String requestId,
    required String rejectionReason,
  }) async {
    final data = await _client
        .from('upi_payment_requests')
        .update({
          'status': 'rejected',
          'rejection_reason': rejectionReason,
        })
        .eq('id', requestId)
        .eq('status', 'pending')
        .select()
        .single();
    return UpiPaymentRequest.fromJson(data);
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `dart analyze lib/features/payments/data/repositories/upi_payment_repository.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/payments/data/repositories/upi_payment_repository.dart
git commit -m "feat(upi): add UPI payment repository"
```

---

## Task 6: UPI Riverpod Providers

**Files:**
- Create: `lib/features/payments/data/providers/upi_providers.dart`

**Interfaces:**
- Consumes: `supabaseClientProvider`, `currentOrgIdOrThrowProvider`, `currentCustomerIdSyncProvider`
- Produces: `upiServiceProvider`, `upiRepositoryProvider`, `pendingUpiRequestsProvider`, `allUpiRequestsProvider`

- [ ] **Step 1: Create providers**

```dart
// lib/features/payments/data/providers/upi_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../customer_portal/data/providers/customer_member_provider.dart';
import '../repositories/upi_payment_repository.dart';
import '../services/upi_service.dart';

final upiRepositoryProvider = Provider<UpiPaymentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return UpiPaymentRepository(client, orgId);
});

final upiServiceProvider = Provider<UpiService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return UpiService(client, orgId);
});

/// Pending UPI requests for the org (staff/admin/manager view).
final pendingUpiRequestsProvider =
    FutureProvider<List<dynamic>>((ref) async {
  final repository = ref.watch(upiRepositoryProvider);
  return repository.getPendingRequests();
});

/// All UPI requests for the org with optional status filter.
final allUpiRequestsProvider =
    FutureProvider.family<List<dynamic>, String?>((ref, status) async {
  final repository = ref.watch(upiRepositoryProvider);
  return repository.getOrgRequests(status: status);
});

/// UPI requests for the current customer.
final customerUpiRequestsProvider =
    FutureProvider<List<dynamic>>((ref) async {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return [];
  final repository = ref.watch(upiRepositoryProvider);
  return repository.getCustomerRequests(customerId);
});

/// Checks if a pending UPI payment exists for a specific EMI.
final hasPendingUpiProvider =
    FutureProvider.family<bool, String>((ref, emiScheduleId) async {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return false;
  final repository = ref.watch(upiRepositoryProvider);
  return repository.checkExistingPending(
    emiScheduleId: emiScheduleId,
    customerId: customerId,
  );
});
```

- [ ] **Step 2: Run analyzer**

Run: `dart analyze lib/features/payments/data/providers/upi_providers.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/payments/data/providers/upi_providers.dart
git commit -m "feat(upi): add UPI Riverpod providers"
```

---

## Task 7: UPI Payment Bottom Sheet (Customer Portal)

**Files:**
- Create: `lib/features/payments/presentation/widgets/upi_payment_sheet.dart`

**Interfaces:**
- Consumes: `UpiService.buildUpiUri`, `QrPng.generate`, `UpiPaymentRepository.createRequest`
- Produces: `UpiPaymentSheet.show()` — bottom sheet with QR + Open UPI + I've Paid

- [ ] **Step 1: Create the bottom sheet widget**

```dart
// lib/features/payments/presentation/widgets/upi_payment_sheet.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/services/upi_service.dart';
import '../../data/repositories/upi_payment_repository.dart';
import '../../data/providers/upi_providers.dart';
import '../../../loans/data/services/qr_png.dart';

class UpiPaymentSheet extends ConsumerStatefulWidget {
  final double amount;
  final String? loanId;
  final String? savingsPlanId;
  final String? emiScheduleId;
  final String? loanNumber;
  final int? emiNumber;
  final String? savingsPlanName;
  final int? installmentNumber;
  final String? memberId;

  const UpiPaymentSheet({
    super.key,
    required this.amount,
    this.loanId,
    this.savingsPlanId,
    this.emiScheduleId,
    this.loanNumber,
    this.emiNumber,
    this.savingsPlanName,
    this.installmentNumber,
    this.memberId,
  });

  static Future<void> show(
    BuildContext context, {
    required double amount,
    String? loanId,
    String? savingsPlanId,
    String? emiScheduleId,
    String? loanNumber,
    int? emiNumber,
    String? savingsPlanName,
    int? installmentNumber,
    String? memberId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpiPaymentSheet(
        amount: amount,
        loanId: loanId,
        savingsPlanId: savingsPlanId,
        emiScheduleId: emiScheduleId,
        loanNumber: loanNumber,
        emiNumber: emiNumber,
        savingsPlanName: savingsPlanName,
        installmentNumber: installmentNumber,
        memberId: memberId,
      ),
    );
  }

  @override
  ConsumerState<UpiPaymentSheet> createState() => _UpiPaymentSheetState();
}

class _UpiPaymentSheetState extends ConsumerState<UpiPaymentSheet> {
  bool _isProcessing = false;
  bool _hasPaid = false;
  Uint8List? _qrBytes;
  String? _upiUri;
  String? _vpa;
  String? _merchantName;

  @override
  void initState() {
    super.initState();
    _loadVpa();
  }

  Future<void> _loadVpa() async {
    final upiService = ref.read(upiServiceProvider);
    final vpaData = await upiService.getOrgVpa();
    if (vpaData == null || !mounted) return;

    final vpa = vpaData['upi_vpa'] as String?;
    final merchantName = vpaData['merchant_name'] as String? ?? '';
    if (vpa == null || vpa.isEmpty) return;

    final note = _buildTransactionNote();
    final uri = UpiService.buildUpiUri(
      vpa: vpa,
      amount: widget.amount,
      merchantName: merchantName,
      transactionNote: note,
    );

    final qr = await QrPng.generate(uri, size: 250);

    if (mounted) {
      setState(() {
        _vpa = vpa;
        _merchantName = merchantName;
        _upiUri = uri;
        _qrBytes = qr;
      });
    }
  }

  String _buildTransactionNote() {
    if (widget.loanId != null && widget.emiNumber != null) {
      return 'Loan ${widget.loanNumber ?? ''} EMI #${widget.emiNumber}';
    }
    if (widget.savingsPlanId != null && widget.installmentNumber != null) {
      return 'Savings ${widget.savingsPlanName ?? ''} Inst #${widget.installmentNumber}';
    }
    return 'Payment';
  }

  Future<void> _openUpiApp() async {
    if (_upiUri == null) return;
    final uri = Uri.parse(_upiUri!);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No UPI app found. Please install Google Pay, PhonePe, or Paytm.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _confirmPaid() async {
    if (_isProcessing || _vpa == null) return;
    setState(() => _isProcessing = true);

    try {
      final repository = ref.read(upiRepositoryProvider);
      await repository.createRequest(
        customerId: '', // Will be set by RLS from auth.uid()
        memberId: widget.memberId,
        loanId: widget.loanId,
        savingsPlanId: widget.savingsPlanId,
        emiScheduleId: widget.emiScheduleId,
        amount: widget.amount,
        upiVpa: _vpa!,
      );

      if (mounted) {
        setState(() => _hasPaid = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment submitted for verification'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Pay via UPI',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),

          // Amount
          Text(
            '₹${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // QR Code
          if (_qrBytes != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Image.memory(
                _qrBytes!,
                width: 200,
                height: 200,
              ),
            )
          else
            const SizedBox(
              width: 200,
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),

          const SizedBox(height: 12),

          // VPA display
          if (_vpa != null)
            Text(
              'VPA: $_vpa',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

          const SizedBox(height: 4),

          // Transaction note
          Text(
            _buildTransactionNote(),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),

          const SizedBox(height: 24),

          // Open UPI App button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _upiUri != null ? _openUpiApp : null,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open UPI App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // I've Paid button
          if (!_hasPaid)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : _confirmPaid,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isProcessing ? 'Submitting...' : "I've Paid"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Payment submitted for verification',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `dart analyze lib/features/payments/presentation/widgets/upi_payment_sheet.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/payments/presentation/widgets/upi_payment_sheet.dart
git commit -m "feat(upi): add UPI payment bottom sheet for customer portal"
```

---

## Task 8: Add "Pay via UPI" Button to Customer EMI Schedule Page

**Files:**
- Modify: `lib/features/customer_portal/presentation/pages/customer_emi_schedule_page.dart`

**Interfaces:**
- Consumes: `UpiPaymentSheet.show()`

- [ ] **Step 1: Read the current file to find the EMI row widget**

The EMI schedule page renders a list of EMI rows. Find the section where unpaid EMIs are displayed and add a "Pay via UPI" button. The exact location is in the EMI list item builder.

- [ ] **Step 2: Add import for UpiPaymentSheet**

Add to imports:
```dart
import '../../../payments/presentation/widgets/upi_payment_sheet.dart';
```

- [ ] **Step 3: Add "Pay via UPI" button in the EMI row**

In the EMI list item, for each unpaid EMI (where `!emi.isPaid`), add a small "Pay" button:

```dart
// Inside the EMI row, after the amount/status display
if (!emi.isPaid && emi.status != 'frozen')
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => UpiPaymentSheet.show(
          context,
          amount: emi.emiAmount,
          loanId: loanId,
          emiScheduleId: emi.id,
          loanNumber: loan?.loanNumber,
          emiNumber: emi.emiNumber,
          memberId: loan?.customerId,
        ),
        icon: const Icon(Icons.payment, size: 16),
        label: const Text('Pay via UPI'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
    ),
  ),
```

- [ ] **Step 4: Run analyzer**

Run: `dart analyze lib/features/customer_portal/presentation/pages/customer_emi_schedule_page.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/features/customer_portal/presentation/pages/customer_emi_schedule_page.dart
git commit -m "feat(upi): add Pay via UPI button to customer EMI schedule"
```

---

## Task 9: Add "Pay via UPI" Button to Customer Loan Detail Page

**Files:**
- Modify: `lib/features/customer_portal/presentation/pages/customer_loan_detail_page.dart`

**Interfaces:**
- Consumes: `UpiPaymentSheet.show()`

- [ ] **Step 1: Add import for UpiPaymentSheet**

```dart
import '../../../payments/presentation/widgets/upi_payment_sheet.dart';
```

- [ ] **Step 2: Add "Pay via UPI" button in the action buttons section**

In the loan detail page, find the action buttons area (around the EMI schedule button and statement download button) and add a "Pay via UPI" button:

```dart
// After the existing action buttons
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () {
      // Find the first unpaid EMI
      final unpaidEmis = emiSchedule.where((e) => !e.isPaid && e.status != 'frozen').toList();
      if (unpaidEmis.isNotEmpty) {
        final nextEmi = unpaidEmis.first;
        UpiPaymentSheet.show(
          context,
          amount: nextEmi.emiAmount,
          loanId: loanId,
          emiScheduleId: nextEmi.id,
          loanNumber: loan?.loanNumber,
          emiNumber: nextEmi.emiNumber,
          memberId: loan?.customerId,
        );
      }
    },
    icon: const Icon(Icons.payment),
    label: const Text('Pay via UPI'),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
  ),
),
```

- [ ] **Step 3: Run analyzer**

Run: `dart analyze lib/features/customer_portal/presentation/pages/customer_loan_detail_page.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/features/customer_portal/presentation/pages/customer_loan_detail_page.dart
git commit -m "feat(upi): add Pay via UPI button to customer loan detail page"
```

---

## Task 10: Add "Pay via UPI" Button to Customer Savings Detail Page

**Files:**
- Modify: `lib/features/customer_portal/presentation/pages/customer_savings_detail_page.dart`

**Interfaces:**
- Consumes: `UpiPaymentSheet.show()`

- [ ] **Step 1: Add import for UpiPaymentSheet**

```dart
import '../../../payments/presentation/widgets/upi_payment_sheet.dart';
```

- [ ] **Step 2: Add "Pay via UPI" button**

Find the action buttons section and add:

```dart
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () => UpiPaymentSheet.show(
      context,
      amount: savingsPlan.monthlyDeposit,
      savingsPlanId: savingsPlan.id,
      savingsPlanName: savingsPlan.planName,
      installmentNumber: (savingsPlan.currentAmount ~/ savingsPlan.monthlyDeposit) + 1,
      memberId: memberId,
    ),
    icon: const Icon(Icons.payment),
    label: const Text('Pay via UPI'),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
  ),
),
```

- [ ] **Step 3: Run analyzer**

Run: `dart analyze lib/features/customer_portal/presentation/pages/customer_savings_detail_page.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/features/customer_portal/presentation/pages/customer_savings_detail_page.dart
git commit -m "feat(upi): add Pay via UPI button to customer savings detail"
```

---

## Task 11: UPI Confirmations Page (Staff/Admin/Manager)

**Files:**
- Create: `lib/features/payments/presentation/pages/upi_confirmations_page.dart`
- Create: `lib/features/payments/presentation/widgets/upi_confirm_dialog.dart`

**Interfaces:**
- Consumes: `pendingUpiRequestsProvider`, `UpiPaymentRepository.confirmPayment`, `UpiPaymentRepository.rejectPayment`
- Produces: Full page with pending list, confirm/reject actions

- [ ] **Step 1: Create the confirm/reject dialog**

```dart
// lib/features/payments/presentation/widgets/upi_confirm_dialog.dart
import 'package:flutter/material.dart';

class UpiConfirmDialog extends StatefulWidget {
  final String title;
  final String? initialReason;

  const UpiConfirmDialog({
    super.key,
    required this.title,
    this.initialReason,
  });

  @override
  State<UpiConfirmDialog> createState() => _UpiConfirmDialogState();
}

class _UpiConfirmDialogState extends State<UpiConfirmDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialReason ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Enter reason...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Create the UPI confirmations page**

```dart
// lib/features/payments/presentation/pages/upi_confirmations_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/upi_providers.dart';
import '../../data/models/upi_payment_request_model.dart';
import '../widgets/upi_confirm_dialog.dart';

class UpiConfirmationsPage extends ConsumerStatefulWidget {
  const UpiConfirmationsPage({super.key});

  @override
  ConsumerState<UpiConfirmationsPage> createState() => _UpiConfirmationsPageState();
}

class _UpiConfirmationsPageState extends ConsumerState<UpiConfirmationsPage> {
  String _filter = 'pending';

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allUpiRequestsProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Payment Confirmations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allUpiRequestsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('pending', 'Pending'),
                const SizedBox(width: 8),
                _buildFilterChip('confirmed', 'Confirmed'),
                const SizedBox(width: 8),
                _buildFilterChip('rejected', 'Rejected'),
                const SizedBox(width: 8),
                _buildFilterChip(null, 'All'),
              ],
            ),
          ),

          // List
          Expanded(
            child: requestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_filter ?? ''} UPI payments',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = UpiPaymentRequest.fromJson(requests[index] as Map<String, dynamic>);
                    return _buildRequestCard(req);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? value, String label) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value ?? 'pending'),
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildRequestCard(UpiPaymentRequest req) {
    final typeLabel = req.isLoanPayment
        ? 'Loan EMI #${req.emiScheduleId != null ? '' : ''}'
        : 'Savings Inst.';
    final amountLabel = '₹${req.amount.toStringAsFixed(2)}';
    final timeAgo = _formatTimeAgo(req.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(Icons.person, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.customerId.substring(0, 8),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$typeLabel • $amountLabel',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'VPA: ${req.upiVpa}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            if (req.status == 'confirmed')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('Confirmed', style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
            if (req.status == 'rejected')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Rejected: ${req.rejectionReason ?? ''}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            if (req.status == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectPayment(req),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmPayment(req),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Confirm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  Future<void> _confirmPayment(UpiPaymentRequest req) async {
    final repository = ref.read(upiRepositoryProvider);
    try {
      await repository.confirmPayment(requestId: req.id, confirmedBy: '');
      ref.invalidate(allUpiRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectPayment(UpiPaymentRequest req) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const UpiConfirmDialog(title: 'Reject Payment'),
    );
    if (reason == null || reason.trim().isEmpty) return;

    final repository = ref.read(upiRepositoryProvider);
    try {
      await repository.rejectPayment(requestId: req.id, rejectionReason: reason);
      ref.invalidate(allUpiRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
```

- [ ] **Step 3: Run analyzer**

Run: `dart analyze lib/features/payments/presentation/pages/upi_confirmations_page.dart lib/features/payments/presentation/widgets/upi_confirm_dialog.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/features/payments/presentation/pages/upi_confirmations_page.dart lib/features/payments/presentation/widgets/upi_confirm_dialog.dart
git commit -m "feat(upi): add UPI confirmations page for staff/admin/manager"
```

---

## Task 12: Add Route for UPI Confirmations Page

**Files:**
- Modify: `lib/core/routes/app_router.dart`

**Interfaces:**
- Consumes: `UpiConfirmationsPage`

- [ ] **Step 1: Add import**

```dart
import '../features/payments/presentation/pages/upi_confirmations_page.dart';
```

- [ ] **Step 2: Add route**

Find the admin shell routes or staff shell routes and add:

```dart
GoRoute(
  path: '/settings/upi-confirmations',
  name: 'upi-confirmations',
  builder: (context, state) => const UpiConfirmationsPage(),
),
```

- [ ] **Step 3: Run analyzer**

Run: `dart analyze lib/core/routes/app_router.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/core/routes/app_router.dart
git commit -m "feat(upi): add route for UPI confirmations page"
```

---

## Task 13: UPI Config Section in Organization Settings

**Files:**
- Modify: `lib/features/settings/presentation/pages/organization_settings_page.dart`

**Interfaces:**
- Consumes: `UpiService.saveOrgVpa`, `UpiService.getOrgVpa`, `UpiService.isValidVpa`

- [ ] **Step 1: Add imports**

```dart
import '../../../payments/data/services/upi_service.dart';
import '../../../payments/data/providers/upi_providers.dart';
```

- [ ] **Step 2: Add UPI config section**

After the existing "Contact" section and before "Financial & Locale", add a new `_Section` widget:

```dart
// Payment Configuration section
_Section(
  icon: Icons.payment,
  title: 'Payment Configuration',
  children: [
    _buildLabel('UPI VPA (Virtual Payment Address)'),
    _buildTextField(
      controller: _upiVpaController,
      hint: 'merchant@upi',
    ),
    const SizedBox(height: 4),
    Text(
      'Format: name@bank (e.g. abc@upi)',
      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
    ),
    const SizedBox(height: 16),
    _buildLabel('Merchant Display Name'),
    _buildTextField(
      controller: _merchantNameController,
      hint: 'My Finance Organization',
    ),
    const SizedBox(height: 4),
    Text(
      'Shown in UPI apps during payment',
      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
    ),
    const SizedBox(height: 16),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _savePaymentSettings,
        child: const Text('Save Payment Settings'),
      ),
    ),
  ],
),
```

- [ ] **Step 3: Add controllers and save method**

In the `_OrganizationSettingsPageState` class:

```dart
final _upiVpaController = TextEditingController();
final _merchantNameController = TextEditingController();

// In _hydrate(), add:
final payment = settings?['payment'] as Map<String, dynamic>?;
_upiVpaController.text = payment?['upi_vpa']?.toString() ?? '';
_merchantNameController.text = payment?['merchant_name']?.toString() ?? '';

// Add save method:
Future<void> _savePaymentSettings() async {
  final vpa = _upiVpaController.text.trim();
  final merchantName = _merchantNameController.text.trim();

  if (vpa.isNotEmpty && !UpiService.isValidVpa(vpa)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid VPA format. Must contain @')),
    );
    return;
  }

  try {
    final upiService = ref.read(upiServiceProvider);
    await upiService.saveOrgVpa(vpa: vpa, merchantName: merchantName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment settings saved')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

- [ ] **Step 4: Run analyzer**

Run: `dart analyze lib/features/settings/presentation/pages/organization_settings_page.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/pages/organization_settings_page.dart
git commit -m "feat(upi): add UPI payment config section to organization settings"
```

---

## Task 14: Add UPI Confirmations Quick Action to Staff Dashboard

**Files:**
- Modify: `lib/features/staff/presentation/pages/staff_home_dashboard.dart`

**Interfaces:**
- Consumes: GoRouter navigation to `/settings/upi-confirmations`

- [ ] **Step 1: Add UPI Confirmations quick action**

Find the quick actions grid in the staff dashboard and add a new action:

```dart
// Add to quick actions list
QuickAction(
  icon: Icons.phone_android,
  label: 'UPI Confirm',
  color: Colors.green,
  onTap: () => context.push('/settings/upi-confirmations'),
),
```

- [ ] **Step 2: Run analyzer**

Run: `dart analyze lib/features/staff/presentation/pages/staff_home_dashboard.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/staff/presentation/pages/staff_home_dashboard.dart
git commit -m "feat(upi): add UPI confirmations quick action to staff dashboard"
```

---

## Task 15: Update Integrations Page — Mark UPI as Implemented

**Files:**
- Modify: `lib/features/settings/presentation/pages/integrations_settings_page.dart`

**Interfaces:**
- Consumes: None (UI-only change)

- [ ] **Step 1: Update UPI Organization Hook status**

Find the UPI Organization Hook card and change:
- Status from P2 roadmap to "Implemented" 
- Remove the "Development pipeline schedule" badge
- Add a "Configure" button that navigates to org settings

- [ ] **Step 2: Commit**

```bash
git add lib/features/settings/presentation/pages/integrations_settings_page.dart
git commit -m "feat(upi): mark UPI Organization Hook as implemented in integrations"
```

---

## Task 16: End-to-End Verification

- [ ] **Step 1: Run all tests**

Run: `dart test`
Expected: All existing tests pass

- [ ] **Step 2: Run analyzer on full project**

Run: `dart analyze`
Expected: No new errors

- [ ] **Step 3: Manual smoke test**

1. Admin opens Organization Settings → Payment Configuration → enters VPA and merchant name → saves
2. Customer opens loan detail → taps "Pay via UPI" → QR code appears → taps "Open UPI App" → UPI app opens with correct amount/VPA
3. Customer taps "I've Paid" → toast "Payment submitted for verification"
4. Staff opens UPI Confirmations page → sees the pending request → taps "Confirm"
5. EMI status updates to paid → loan balance updates

- [ ] **Step 4: Commit final state**

```bash
git add -A
git commit -m "feat(upi): complete UPI payment feature implementation"
```
