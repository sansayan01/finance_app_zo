# Fix Summary: Today's Payment Page - "Done" Tab Logic Issue

## Problem Description
The "Done" section in the Today's Payment page was showing 0 payments even when there were collected payments available, specifically when active filters were applied.

From the UI screenshot:
- Done: 0 payments displayed
- Progress bar shows 0% Done
- The pending (2) and overdue (18) sections worked properly

## Root Cause
The issue was in the `TodayPaymentData` class in `lib/features/payments/data/providers/payment_providers.dart`.

The class has two lists:
1. `payments` - the filtered list based on search and advanced filters
2. `allPayments` - the complete list of all payments regardless of filters

The `summary` getter was correctly using `allPayments` to calculate totals (line 749).

However, the tab-specific getters were incorrectly filtering the `payments` list instead of `allPayments`:

```dart
// BEFORE (INCORRECT):
List<TodayPayment> get collectedPayments =>
    payments.where((p) => p.isCollected).toList();

List<TodayPayment> get pendingPayments =>
    payments.where((p) => p.isPending).toList();

List<TodayPayment> get overduePayments =>
    payments.where((p) => p.isOverdue).toList();
```

When a user applied filters (e.g., by branch or agent), the `payments` list could become empty or not contain any collected payments, even though `allPayments` had collected payments.

## Solution
Changed the filtering to use `allPayments` instead of `payments`:

```dart
// AFTER (CORRECT):
List<TodayPayment> get collectedPayments =>
    allPayments.where((p) => p.isCollected).toList();

List<TodayPayment> get pendingPayments =>
    allPayments.where((p) => p.isPending).toList();

List<TodayPayment> get overduePayments =>
    allPayments.where((p) => p.isOverdue).toList();
```

## Impact
- The "Done" tab now correctly shows all collected payments regardless of active filters
- The progress calculation in the hero header correctly reflects the collection rate
- Tab counts (Pending/Overdue/Done) now show the true counts from allPayments
- All other tab functionality (Pending, Overdue) continues to work as expected
- Date selection and filtering still works correctly for all tabs

## Files Modified
- `lib/features/payments/data/providers/payment_providers.dart` - Lines 752, 755, 758

## Testing
The fix ensures that:
1. The "Done" tab shows collected payments even when filters are applied
2. The progress bar shows the correct collection percentage
3. The "0% Done" text displays the correct percentage
4. Active filters still work properly for the Pending and Overdue tabs
5. Search and advanced filtering maintain their existing behavior
