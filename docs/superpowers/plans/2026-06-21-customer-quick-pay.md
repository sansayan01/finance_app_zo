# Customer Quick Pay — Bulk UPI Installment Payments

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let customers select and pay multiple pending installments (EMI or savings) in a single UPI transaction instead of one at a time.

**Architecture:** Per-loan/per-savings quick pay pages reuse the staff's `EmiPaymentSelector`/`SavingsPaymentSelector` counter and calendar patterns. Single UPI payment creates multiple `upi_payment_request` rows. Staff confirms per-row; `collections` records are created using the customer's payment time.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase, existing `upi://pay` deep links

## Global Constraints

- Feature-first architecture: `lib/features/<feature>/data/` and `lib/features/<feature>/presentation/`
- Riverpod for state management
- go_router for navigation with portal shells (CustomerShell, StaffShell, AdminShell)
- RLS uses `get_user_org_id()` and `get_user_role()` SQL functions (NOT `user_org_roles` table)
- Role strings: `executiveAdmin`, `manager`, `collectionAgent`
- Supabase PostgREST for all data access
- Existing `EmiPaymentSelector` at `lib/features/loans/presentation/widgets/emi_payment_selector.dart` emits `List<EMIScheduleModel>` via `onSelectionChanged`
- Existing `SavingsPaymentSelector` at `lib/features/savings/presentation/widgets/savings_payment_selector.dart` emits `List<SavingsInstallment>` via `onSelectionChanged`
- `collection_date` on `collections` records MUST use the customer's payment time (`upi_payment_requests.created_at`), NOT the staff confirmation time
- Calendar opens immediately on "Choose Dates" tab (no extra tap)

---

### Task 1: Modify UpiPaymentSheet for Batch Payments

**Files:**
- Modify: `lib/features/payments/presentation/widgets/upi_payment_sheet.dart`

**Interfaces:**
- Consumes: `UpiPaymentRepository.createRequest()` (already exists), `UpiService.buildUpiUri()` (already exists), `QrPng.generate()` (already exists)
- Produces: Modified `UpiPaymentSheet.show()` accepts batch parameters and creates multiple `upi_payment_request` rows on "I've Paid"

- [ ] **Step 1: Add batch parameters to UpiPaymentSheet**

Add these new optional parameters to the widget and its `show()` static method:

```dart
// In the UpiPaymentSheet class — add after existing params:
final List<String>? emiScheduleIds;       // batch of EMI IDs
final List<double>? emiAmounts;           // batch of per-EMI amounts
final List<String>? savingsDateKeys;      // batch of savings installment date keys
final List<double>? savingsAmounts;       // batch of per-installment amounts
final String? transactionNoteOverride;    // custom batch note text
```

Update the constructor and `show()` method to pass these through:

```dart
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
  // Batch params
  List<String>? emiScheduleIds,
  List<double>? emiAmounts,
  List<String>? savingsDateKeys,
  List<double>? savingsAmounts,
  String? transactionNoteOverride,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
      emiScheduleIds: emiScheduleIds,
      emiAmounts: emiAmounts,
      savingsDateKeys: savingsDateKeys,
      savingsAmounts: savingsAmounts,
      transactionNoteOverride: transactionNoteOverride,
    ),
  );
}
```

- [ ] **Step 2: Update _buildTransactionNote() for batch mode**

Replace the existing `_buildTransactionNote()` method:

```dart
String _buildTransactionNote() {
  // Batch mode — use override note if provided
  if (widget.transactionNoteOverride != null) {
    return widget.transactionNoteOverride!;
  }

  // Single EMI mode (existing behavior)
  if (widget.loanId != null && widget.emiNumber != null) {
    return 'Loan ${widget.loanNumber ?? ''} EMI #${widget.emiNumber}';
  }
  if (widget.savingsPlanId != null && widget.installmentNumber != null) {
    return 'Savings ${widget.savingsPlanName ?? ''} Inst #${widget.installmentNumber}';
  }
  return 'Payment';
}
```

- [ ] **Step 3: Update _confirmPaid() for batch mode**

Replace the existing `_confirmPaid()` method to loop when batch IDs are provided:

```dart
Future<void> _confirmPaid() async {
  if (_isProcessing || _vpa == null) return;
  setState(() => _isProcessing = true);

  try {
    final repository = ref.read(upiRepositoryProvider);

    // Batch mode — create one request per installment
    final hasBatchEmis = widget.emiScheduleIds != null && widget.emiScheduleIds!.isNotEmpty;
    final hasBatchSavings = widget.savingsDateKeys != null && widget.savingsDateKeys!.isNotEmpty;

    if (hasBatchEmis) {
      for (var i = 0; i < widget.emiScheduleIds!.length; i++) {
        await repository.createRequest(
          customerId: '',
          memberId: widget.memberId,
          loanId: widget.loanId,
          emiScheduleId: widget.emiScheduleIds![i],
          amount: widget.emiAmounts![i],
          upiVpa: _vpa!,
        );
      }
    } else if (hasBatchSavings) {
      for (var i = 0; i < widget.savingsDateKeys!.length; i++) {
        await repository.createRequest(
          customerId: '',
          memberId: widget.memberId,
          savingsPlanId: widget.savingsPlanId,
          amount: widget.savingsAmounts![i],
          upiVpa: _vpa!,
        );
      }
    } else {
      // Single installment mode (existing behavior)
      await repository.createRequest(
        customerId: '',
        memberId: widget.memberId,
        loanId: widget.loanId,
        savingsPlanId: widget.savingsPlanId,
        emiScheduleId: widget.emiScheduleId,
        amount: widget.amount,
        upiVpa: _vpa!,
      );
    }

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
```

- [ ] **Step 4: Run analyzer and commit**

```
dart analyze lib/features/payments/presentation/widgets/upi_payment_sheet.dart
```

```bash
git add lib/features/payments/presentation/widgets/upi_payment_sheet.dart
git commit -m "feat(quick-pay): add batch support to UpiPaymentSheet"
```

---

### Task 2: Create Customer Loan Quick Pay Page

**Files:**
- Create: `lib/features/customer_portal/presentation/pages/customer_loan_quick_pay_page.dart`

**Interfaces:**
- Consumes: `EmiPaymentSelector` widget (from `loans/presentation/widgets/emi_payment_selector.dart`), `UpiPaymentSheet.show()` (from Task 1), `customerLoansProvider` (existing), `customerEmiScheduleProvider` (existing)
- Produces: `CustomerLoanQuickPayPage` widget with `loanId` param

- [ ] **Step 1: Create the CustomerLoanQuickPayPage**

Create `lib/features/customer_portal/presentation/pages/customer_loan_quick_pay_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/customer_loans_providers.dart';
import '../../../loans/data/models/emi_schedule_model.dart';
import '../../../loans/presentation/widgets/emi_payment_selector.dart';
import '../../../payments/presentation/widgets/upi_payment_sheet.dart';

class CustomerLoanQuickPayPage extends ConsumerStatefulWidget {
  final String loanId;

  const CustomerLoanQuickPayPage({super.key, required this.loanId});

  @override
  ConsumerState<CustomerLoanQuickPayPage> createState() => _CustomerLoanQuickPayPageState();
}

class _CustomerLoanQuickPayPageState extends ConsumerState<CustomerLoanQuickPayPage> {
  List<EMIScheduleModel> _selectedEmis = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emisAsync = ref.watch(customerEmiScheduleProvider(widget.loanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay via UPI'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: emisAsync.when(
        data: (emis) {
          if (emis.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('All EMIs are paid!', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          final unpaidEmis = emis.where((e) => e.status != 'paid').toList();
          if (unpaidEmis.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('All EMIs are paid!', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          final emiAmount = unpaidEmis.isNotEmpty ? unpaidEmis.first.amount : 0.0;

          return Column(
            children: [
              // Header summary
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${emiAmount.toStringAsFixed(0)} / EMI',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${unpaidEmis.length} installments remaining',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Selector
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmiPaymentSelector(
                    emis: unpaidEmis,
                    emiAmount: emiAmount,
                    onSelectionChanged: (selected) {
                      setState(() => _selectedEmis = selected);
                    },
                  ),
                ),
              ),

              // Bottom bar
              _buildBottomBar(emiAmount),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBottomBar(double emiAmount) {
    final totalSelected = _selectedEmis.fold<double>(0, (sum, e) => sum + e.amount);
    final count = _selectedEmis.length;
    final isEnabled = count > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected: $count · ₹${totalSelected.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isEnabled ? AppColors.primary : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isEnabled ? _openUpiPayment : null,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text('Pay ₹${totalSelected.toStringAsFixed(0)} via UPI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openUpiPayment() {
    final totalAmount = _selectedEmis.fold<double>(0, (sum, e) => sum + e.amount);
    final emiIds = _selectedEmis.map((e) => e.id).toList();
    final emiAmounts = _selectedEmis.map((e) => e.amount).toList();
    final emiNumbers = _selectedEmis.map((e) => e.emiNumber).toList();

    final note = 'EMI #${emiNumbers.join(", ")} · ₹${totalAmount.toStringAsFixed(0)}';

    HapticFeedback.lightImpact();
    UpiPaymentSheet.show(
      context,
      amount: totalAmount,
      loanId: widget.loanId,
      emiScheduleIds: emiIds,
      emiAmounts: emiAmounts,
      transactionNoteOverride: note,
    );
  }
}
```

**NOTE:** The `customerEmiScheduleProvider` and `EMIScheduleModel` field names (`.id`, `.amount`, `.emiNumber`, `.status`) must be verified against the existing model. Read the model file first and adjust accordingly.

- [ ] **Step 2: Run analyzer and commit**

```
dart analyze lib/features/customer_portal/presentation/pages/customer_loan_quick_pay_page.dart
```

```bash
git add lib/features/customer_portal/presentation/pages/customer_loan_quick_pay_page.dart
git commit -m "feat(quick-pay): create customer loan quick pay page"
```

---

### Task 3: Create Customer Savings Quick Pay Page

**Files:**
- Create: `lib/features/customer_portal/presentation/pages/customer_savings_quick_pay_page.dart`

**Interfaces:**
- Consumes: `SavingsPaymentSelector` widget (from `savings/presentation/widgets/savings_payment_selector.dart`), `UpiPaymentSheet.show()` (from Task 1)
- Produces: `CustomerSavingsQuickPayPage` widget with `savingsPlanId` param

- [ ] **Step 1: Create the CustomerSavingsQuickPayPage**

Create `lib/features/customer_portal/presentation/pages/customer_savings_quick_pay_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/customer_savings_providers.dart';
import '../../../savings/data/models/savings_installment_model.dart';
import '../../../savings/presentation/widgets/savings_payment_selector.dart';
import '../../../payments/presentation/widgets/upi_payment_sheet.dart';

class CustomerSavingsQuickPayPage extends ConsumerStatefulWidget {
  final String savingsPlanId;

  const CustomerSavingsQuickPayPage({super.key, required this.savingsPlanId});

  @override
  ConsumerState<CustomerSavingsQuickPayPage> createState() => _CustomerSavingsQuickPayPageState();
}

class _CustomerSavingsQuickPayPageState extends ConsumerState<CustomerSavingsQuickPayPage> {
  List<SavingsInstallment> _selectedInstallments = [];

  @override
  Widget build(BuildContext context) {
    final savingsAsync = ref.watch(customerSavingsInstallmentsProvider(widget.savingsPlanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay via UPI'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: savingsAsync.when(
        data: (result) {
          final installments = result.installments;
          final planName = result.planName;
          final installmentAmount = result.installmentAmount;

          if (installments.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('All installments are paid!', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          final unpaid = installments.where((i) => !i.isPaid).toList();
          if (unpaid.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('All installments are paid!', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Header summary
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.savings, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${installmentAmount.toStringAsFixed(0)} / installment',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${unpaid.length} installments remaining · $planName',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Selector
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SavingsPaymentSelector(
                    installments: unpaid,
                    installmentAmount: installmentAmount,
                    totalInstallments: installments.length,
                    onSelectionChanged: (selected) {
                      setState(() => _selectedInstallments = selected);
                    },
                  ),
                ),
              ),

              // Bottom bar
              _buildBottomBar(installmentAmount),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBottomBar(double installmentAmount) {
    final totalSelected = _selectedInstallments.fold<double>(0, (sum, e) => sum + e.amount);
    final count = _selectedInstallments.length;
    final isEnabled = count > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected: $count · ₹${totalSelected.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isEnabled ? AppColors.primary : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isEnabled ? _openUpiPayment : null,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text('Pay ₹${totalSelected.toStringAsFixed(0)} via UPI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openUpiPayment() {
    final totalAmount = _selectedInstallments.fold<double>(0, (sum, e) => sum + e.amount);
    final dateKeys = _selectedInstallments.map((e) => e.dateKey).toList();
    final amounts = _selectedInstallments.map((e) => e.amount).toList();
    final dates = _selectedInstallments.map((e) => e.date).toList();

    final note = 'Installment ${dates.join(", ")} · ₹${totalAmount.toStringAsFixed(0)}';

    HapticFeedback.lightImpact();
    UpiPaymentSheet.show(
      context,
      amount: totalAmount,
      savingsPlanId: widget.savingsPlanId,
      savingsDateKeys: dateKeys,
      savingsAmounts: amounts,
      transactionNoteOverride: note,
    );
  }
}
```

**NOTE:** The `customerSavingsInstallmentsProvider` and `SavingsInstallment` field names (`.dateKey`, `.amount`, `.isPaid`, `.date`, `.amount`) must be verified against the existing model. Read the model file first and adjust accordingly. The provider must return an object with `.installments`, `.planName`, `.installmentAmount` — check what the existing provider returns and adapt.

- [ ] **Step 2: Run analyzer and commit**

```
dart analyze lib/features/customer_portal/presentation/pages/customer_savings_quick_pay_page.dart
```

```bash
git add lib/features/customer_portal/presentation/pages/customer_savings_quick_pay_page.dart
git commit -m "feat(quick-pay): create customer savings quick pay page"
```

---

### Task 4: Add Quick Pay Routes

**Files:**
- Modify: `lib/router/app_router.dart`

**Interfaces:**
- Consumes: `CustomerLoanQuickPayPage` (Task 2), `CustomerSavingsQuickPayPage` (Task 3)
- Produces: Two new routes under CustomerShell

- [ ] **Step 1: Add imports at the top of app_router.dart**

```dart
import '../features/customer_portal/presentation/pages/customer_loan_quick_pay_page.dart';
import '../features/customer_portal/presentation/pages/customer_savings_quick_pay_page.dart';
```

- [ ] **Step 2: Add routes inside CustomerShell's routes list**

Find the existing customer loan detail and savings detail routes. Add quick pay routes near them:

```dart
GoRoute(
  path: 'loan/:loanId/quick-pay',
  builder: (context, state) {
    final id = state.pathParameters['loanId']!;
    return CustomerLoanQuickPayPage(loanId: id);
  },
),
GoRoute(
  path: 'savings/:savingsId/quick-pay',
  builder: (context, state) {
    final id = state.pathParameters['savingsId']!;
    return CustomerSavingsQuickPayPage(savingsPlanId: id);
  },
),
```

- [ ] **Step 3: Run analyzer and commit**

```
dart analyze lib/router/app_router.dart
```

```bash
git add lib/router/app_router.dart
git commit -m "feat(quick-pay): add routes for customer quick pay pages"
```

---

### Task 5: Update Customer Pages to Navigate to Quick Pay

**Files:**
- Modify: `lib/features/customer_portal/presentation/pages/customer_loan_detail_page.dart`
- Modify: `lib/features/customer_portal/presentation/pages/customer_savings_detail_page.dart`
- Modify: `lib/features/customer_portal/presentation/pages/customer_emi_schedule_page.dart`

**Interfaces:**
- Consumes: `CustomerLoanQuickPayPage` route (Task 4), `CustomerSavingsQuickPayPage` route (Task 4)
- Produces: Existing "Pay via UPI" buttons now navigate to quick pay pages

- [ ] **Step 1: Update customer_loan_detail_page.dart**

Find the existing "Pay via UPI" button. Replace the `UpiPaymentSheet.show(...)` call with a navigation to the quick pay page:

```dart
// OLD:
UpiPaymentSheet.show(
  context,
  amount: loan.emiAmount,
  loanId: widget.loanId,
  memberId: memberId,
);

// NEW:
context.push('/customer/loan/${widget.loanId}/quick-pay');
```

Remove the `upi_payment_sheet.dart` import if it's no longer used. Add `go_router` import if not already present.

- [ ] **Step 2: Update customer_savings_detail_page.dart**

Find the existing "Pay via UPI" button. Replace the `UpiPaymentSheet.show(...)` call:

```dart
// OLD:
UpiPaymentSheet.show(
  context,
  amount: savings.monthlyDeposit,
  savingsPlanId: widget.savingsId,
  memberId: memberId,
);

// NEW:
context.push('/customer/savings/${widget.savingsId}/quick-pay');
```

- [ ] **Step 3: Update customer_emi_schedule_page.dart**

Find the existing `_upiPayButton` method or the UPI button in the header. Replace the `UpiPaymentSheet.show(...)` call:

```dart
// OLD:
UpiPaymentSheet.show(
  context,
  amount: totalPending,
  loanId: widget.loanId,
  loanNumber: ...,
);

// NEW:
context.push('/customer/loan/${widget.loanId}/quick-pay');
```

- [ ] **Step 4: Run analyzer on all 3 files and commit**

```
dart analyze lib/features/customer_portal/presentation/pages/customer_loan_detail_page.dart lib/features/customer_portal/presentation/pages/customer_savings_detail_page.dart lib/features/customer_portal/presentation/pages/customer_emi_schedule_page.dart
```

```bash
git add lib/features/customer_portal/presentation/pages/customer_loan_detail_page.dart lib/features/customer_portal/presentation/pages/customer_savings_detail_page.dart lib/features/customer_portal/presentation/pages/customer_emi_schedule_page.dart
git commit -m "feat(quick-pay): redirect customer UPI buttons to quick pay pages"
```

---

### Task 6: Enhance Repository with Batch Confirm + Collection Creation

**Files:**
- Modify: `lib/features/payments/data/repositories/upi_payment_repository.dart`

**Interfaces:**
- Consumes: `UpiPaymentRequest` model (existing), Supabase `collections` table (existing)
- Produces: `confirmBatch()` method that confirms multiple requests and creates `collections` records

- [ ] **Step 1: Add confirmBatch method to UpiPaymentRepository**

Add this method after the existing `confirmPayment()` method:

```dart
/// Confirms a batch of UPI requests and creates collection records.
/// Uses each request's created_at as the collection_date (customer's payment time).
Future<void> confirmBatch({
  required List<String> requestIds,
  required String confirmedBy,
}) async {
  if (requestIds.isEmpty) return;

  // 1. Fetch all requests being confirmed
  final requestData = await _client
      .from('upi_payment_requests')
      .select()
      .inFilter('id', requestIds)
      .eq('status', 'pending');

  final requests = (requestData as List)
      .map((e) => UpiPaymentRequest.fromJson(e))
      .toList();

  // 2. Update all request statuses to confirmed
  for (final req in requests) {
    await _client
        .from('upi_payment_requests')
        .update({
          'status': 'confirmed',
          'confirmed_by': confirmedBy,
          'confirmed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', req.id);
  }

  // 3. Create collection records using customer's payment time
  for (final req in requests) {
    final collectionDate = req.createdAt.toIso8601String().substring(0, 10); // YYYY-MM-DD

    await _client.from('collections').insert({
      'org_id': _orgId,
      'loan_id': req.loanId,
      'member_id': req.memberId,
      'staff_id': confirmedBy,
      'amount_collected': req.amount,
      'payment_mode': 'upi',
      'collection_date': collectionDate,
      'remarks': 'UPI payment confirmed — ID: ${req.id}',
    });
  }
}
```

**NOTE:** Verify the exact column names in the `collections` table by reading the existing `CollectionModel.toSupabaseInsert()` method. Adjust field names to match. The key requirement is that `collection_date` uses the date portion of `req.created_at` (the customer's payment time).

- [ ] **Step 2: Run analyzer and commit**

```
dart analyze lib/features/payments/data/repositories/upi_payment_repository.dart
```

```bash
git add lib/features/payments/data/repositories/upi_payment_repository.dart
git commit -m "feat(quick-pay): add batch confirm with collection record creation"
```

---

### Task 7: Enhance UPI Confirmations Page with Batch Grouping

**Files:**
- Modify: `lib/features/payments/presentation/pages/upi_confirmations_page.dart`

**Interfaces:**
- Consumes: `UpiPaymentRequest` model (existing), `UpiPaymentRepository.confirmBatch()` (Task 6), `UpiPaymentRepository.rejectPayment()` (existing)
- Produces: Grouped batch UI with per-request checkboxes, "Select All" per batch, "Confirm Selected" action

- [ ] **Step 1: Rewrite UpiConfirmationsPage with batch grouping**

Replace the entire file with the batch-grouped version:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/upi_providers.dart';
import '../../data/repositories/upi_payment_repository.dart';
import '../../data/models/upi_payment_request_model.dart';
import '../widgets/upi_confirm_dialog.dart';

class UpiConfirmationsPage extends ConsumerStatefulWidget {
  const UpiConfirmationsPage({super.key});

  @override
  ConsumerState<UpiConfirmationsPage> createState() => _UpiConfirmationsPageState();
}

class _UpiConfirmationsPageState extends ConsumerState<UpiConfirmationsPage> {
  String _filter = 'pending';
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allUpiRequestsProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Payment Confirmations'),
        actions: [
          if (_filter == 'pending' && _selectedIds.isNotEmpty)
            TextButton.icon(
              onPressed: _confirmSelected,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                'Confirm (${_selectedIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allUpiRequestsProvider);
              setState(() => _selectedIds.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
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
                          'No $_filter UPI payments',
                          style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                final typedRequests = requests
                    .map((e) => UpiPaymentRequest.fromJson(e as Map<String, dynamic>))
                    .toList();
                final batches = _groupIntoBatches(typedRequests);

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: batches.length,
                  itemBuilder: (context, index) => _buildBatchCard(batches[index]),
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

  /// Groups requests by customer_id + loan_id/savings_plan_id + created_at within 5 min.
  List<List<UpiPaymentRequest>> _groupIntoBatches(List<UpiPaymentRequest> requests) {
    if (requests.isEmpty) return [];

    final sorted = List<UpiPaymentRequest>.from(requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final batches = <List<UpiPaymentRequest>>[];
    var currentBatch = <UpiPaymentRequest>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];

      final sameCustomer = curr.customerId == prev.customerId;
      final sameLoan = curr.loanId == prev.loanId && curr.loanId != null;
      final sameSavings = curr.savingsPlanId == prev.savingsPlanId && curr.savingsPlanId != null;
      final withinFiveMin = curr.createdAt.difference(prev.createdAt).abs() <= const Duration(minutes: 5);

      if (sameCustomer && (sameLoan || sameSavings) && withinFiveMin) {
        currentBatch.add(curr);
      } else {
        batches.add(currentBatch);
        currentBatch = [curr];
      }
    }
    batches.add(currentBatch);

    return batches;
  }

  Widget _buildBatchCard(List<UpiPaymentRequest> batch) {
    final first = batch.first;
    final total = batch.fold<double>(0, (sum, r) => sum + r.amount);
    final typeLabel = first.isLoanPayment ? 'Loan EMI' : 'Savings Inst.';
    final allSelected = batch.every((r) => _selectedIds.contains(r.id));
    final batchId = '${first.customerId}_${first.loanId ?? first.savingsPlanId}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Batch header
            Row(
              children: [
                Checkbox(
                  value: allSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        for (final r in batch) {
                          _selectedIds.add(r.id);
                        }
                      } else {
                        for (final r in batch) {
                          _selectedIds.remove(r.id);
                        }
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${batch.length} $typeLabel installments',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(0)} total · ${_formatTimeAgo(first.createdAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(),

            // Individual requests
            for (final req in batch)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    if (_filter == 'pending')
                      Checkbox(
                        value: _selectedIds.contains(req.id),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(req.id);
                            } else {
                              _selectedIds.remove(req.id);
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    Icon(
                      req.status == 'confirmed'
                          ? Icons.check_circle
                          : req.status == 'rejected'
                              ? Icons.cancel
                              : Icons.pending,
                      size: 16,
                      color: req.status == 'confirmed'
                          ? Colors.green
                          : req.status == 'rejected'
                              ? Colors.red
                              : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        req.isLoanPayment
                            ? 'EMI #${req.emiScheduleId?.substring(0, 8) ?? '?'}'
                            : 'Installment · ₹${req.amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '₹${req.amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),

            // Status for non-pending
            if (_filter != 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      first.status == 'confirmed' ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: first.status == 'confirmed' ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      first.status == 'confirmed' ? 'Confirmed' : 'Rejected',
                      style: TextStyle(
                        color: first.status == 'confirmed' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
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

  Widget _buildFilterChip(String? value, String label) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filter = value ?? 'pending';
          _selectedIds.clear();
        });
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  Future<void> _confirmSelected() async {
    if (_selectedIds.isEmpty) return;

    final repository = ref.read(upiRepositoryProvider);
    try {
      await repository.confirmBatch(
        requestIds: _selectedIds.toList(),
        confirmedBy: '', // TODO: get current user ID from auth
      );
      ref.invalidate(allUpiRequestsProvider);
      setState(() => _selectedIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedIds.length} payments confirmed'),
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
}
```

- [ ] **Step 2: Run analyzer and commit**

```
dart analyze lib/features/payments/presentation/pages/upi_confirmations_page.dart
```

```bash
git add lib/features/payments/presentation/pages/upi_confirmations_page.dart
git commit -m "feat(quick-pay): add batch grouping to UPI confirmations page"
```

---

### Task 8: End-to-End Verification

**Files:** None (read-only verification)

- [ ] **Step 1: Run full project analyzer**

```
flutter analyze
```

Expected: No issues found.

- [ ] **Step 2: Run all tests**

```
flutter test
```

Expected: All tests pass (pre-existing failures are OK if they existed before).

- [ ] **Step 3: Verify commit log**

```bash
git log --oneline -10
```

Expected: All Task 1-7 commits present with correct messages.

- [ ] **Step 4: Verify no leftover uncommitted changes**

```bash
git status
```

Expected: Clean working tree (except expected untracked dirs like `.superpowers/`).
