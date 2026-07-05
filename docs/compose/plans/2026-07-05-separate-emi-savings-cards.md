# Separate EMI and Savings Cards in Done Section

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modify the "Done" tab in Today's Payments screens to show separate cards for Loan EMI and Savings Installment payments instead of grouping them together by member name.

**Architecture:** Group collected payments by `memberName + type` instead of just `memberName`. Update the card widget to display the payment type (EMI/Savings) alongside the member name. Apply changes to all three payment screens (staff, branch manager, admin).

**Tech Stack:** Flutter, Dart, Riverpod (state management)

## Global Constraints

- Maintain existing design system (colors, typography, spacing)
- Preserve all existing functionality (tap handlers, refresh, animations)
- Follow existing code patterns in each file
- No new dependencies required

---

## File Structure

### Files to Modify

| File | Changes |
|------|---------|
| `lib/features/staff/presentation/pages/staff_today_payments_page.dart` | Modify `_buildGroupedCollectedList` and `_GroupedCollectedCard` |
| `lib/features/branch_manager/presentation/pages/branch_today_payments_page.dart` | Same changes as staff page |
| `lib/features/payments/presentation/pages/today_payments_page.dart` | Modify `_GroupedCollectedList` widget |

---

## Task 1: Update Staff Today Payments Page

**Covers:** Separate EMI/Savings cards in staff view

**Files:**
- Modify: `lib/features/staff/presentation/pages/staff_today_payments_page.dart:1138-1182` (`_buildGroupedCollectedList`)
- Modify: `lib/features/staff/presentation/pages/staff_today_payments_page.dart:1907-1997` (`_GroupedCollectedCard`)

**Interfaces:**
- Consumes: `List<TodayPayment> collected`, `bool isDark`, `String branchId`
- Produces: Updated grouping logic and card display

- [ ] **Step 1: Modify `_buildGroupedCollectedList` grouping logic**

Replace the grouping logic at lines 1150-1153:

```dart
// BEFORE:
final Map<String, List<TodayPayment>> grouped = {};
for (final p in collected) {
  grouped.putIfAbsent(p.memberName, () => []).add(p);
}
final memberNames = grouped.keys.toList();
```

With:

```dart
// AFTER:
final Map<String, List<TodayPayment>> grouped = {};
for (final p in collected) {
  final key = '${p.memberName}_${p.type.name}';
  grouped.putIfAbsent(key, () => []).add(p);
}
final groupKeys = grouped.keys.toList();
```

- [ ] **Step 2: Update the ListView.builder to use new grouping**

Replace lines 1161-1179:

```dart
return RefreshIndicator(
  onRefresh: () async {
    HapticFeedback.lightImpact();
    ref.invalidate(branchTodayPaymentsProvider(branchId));
  },
  child: ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    itemCount: groupKeys.length,
    itemBuilder: (context, index) {
      final groupKey = groupKeys[index];
      final payments = grouped[groupKey]!;
      final totalCollected = payments.fold<double>(0, (sum, p) => sum + (p.amountCollected ?? p.amountExpected));
      final representative = payments.first;
      final memberName = representative.memberName;
      final typeLabel = representative.typeLabel;

      return GestureDetector(
          onTap: () => _showPaymentDetails(representative, branchId),
          child: _GroupedCollectedCard(
            memberName: memberName,
            typeLabel: typeLabel,
            payments: payments,
            totalCollected: totalCollected,
            isDark: isDark,
          ),
      );
    },
  ),
);
```

- [ ] **Step 3: Update `_GroupedCollectedCard` to accept and display typeLabel**

Modify the widget constructor at lines 1907-1912:

```dart
class _GroupedCollectedCard extends StatelessWidget {
  final String memberName;
  final String typeLabel;
  final List<TodayPayment> payments;
  final double totalCollected;
  final bool isDark;
  const _GroupedCollectedCard({
    required this.memberName,
    required this.typeLabel,
    required this.payments,
    required this.totalCollected,
    required this.isDark,
  });
```

- [ ] **Step 4: Update the card display to show typeLabel**

Replace the member name display at lines 1950-1961:

```dart
Expanded(
  child: Text(
    '$memberName • $typeLabel',
    style: TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 14,
      letterSpacing: -0.2,
      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
    ),
    overflow: TextOverflow.ellipsis,
  ),
),
```

- [ ] **Step 5: Run the app and verify changes**

Run: `flutter run`
Verify: Navigate to Staff > Payments > Done tab. If a member has both EMI and Savings collected, they should appear as two separate cards.

- [ ] **Step 6: Commit changes**

```bash
git add lib/features/staff/presentation/pages/staff_today_payments_page.dart
git commit -m "feat: separate EMI and savings cards in staff payments Done tab"
```

---

## Task 2: Update Branch Manager Today Payments Page

**Covers:** Separate EMI/Savings cards in branch manager view

**Files:**
- Modify: `lib/features/branch_manager/presentation/pages/branch_today_payments_page.dart:998-1058` (`_buildGroupedCollectedList`)

**Interfaces:**
- Consumes: `List<TodayPayment> collected`, `bool isDark`
- Produces: Updated grouping logic

- [ ] **Step 1: Modify `_buildGroupedCollectedList` grouping logic**

Replace the grouping logic at lines 1025-1029:

```dart
// BEFORE:
final Map<String, List<TodayPayment>> grouped = {};
for (final p in collected) {
  grouped.putIfAbsent(p.memberName, () => []).add(p);
}
final memberNames = grouped.keys.toList();
```

With:

```dart
// AFTER:
final Map<String, List<TodayPayment>> grouped = {};
for (final p in collected) {
  final key = '${p.memberName}_${p.type.name}';
  grouped.putIfAbsent(key, () => []).add(p);
}
final groupKeys = grouped.keys.toList();
```

- [ ] **Step 2: Update the ListView.builder to use new grouping**

Replace lines 1037-1055:

```dart
return RefreshIndicator(
  onRefresh: () async {
    ref.invalidate(branchTodayPaymentsProvider(branchId));
  },
  child: ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    itemCount: groupKeys.length,
    itemBuilder: (context, index) {
      final groupKey = groupKeys[index];
      final payments = grouped[groupKey]!;
      final totalCollected = payments.fold<double>(0, (sum, p) => sum + (p.amountCollected ?? p.amountExpected));
      final representative = payments.first;
      final memberName = representative.memberName;
      final typeLabel = representative.typeLabel;

      return GestureDetector(
          onTap: () => _showPaymentDetails(representative),
          child: _GroupedCollectedCard(
            memberName: memberName,
            typeLabel: typeLabel,
            payments: payments,
            totalCollected: totalCollected,
            isDark: isDark,
          ),
      );
    },
  ),
);
```

- [ ] **Step 3: Update `_GroupedCollectedCard` widget (if it exists in this file)**

Check if `_GroupedCollectedCard` is defined in this file. If it's a shared widget, update it. If it's local, apply the same changes as Task 1 Steps 3-4.

- [ ] **Step 4: Run the app and verify changes**

Run: `flutter run`
Verify: Navigate to Branch Manager > Payments > Done tab. Verify separate cards for EMI and Savings.

- [ ] **Step 5: Commit changes**

```bash
git add lib/features/branch_manager/presentation/pages/branch_today_payments_page.dart
git commit -m "feat: separate EMI and savings cards in branch manager payments Done tab"
```

---

## Task 3: Update Admin Today Payments Page

**Covers:** Separate EMI/Savings cards in admin view

**Files:**
- Modify: `lib/features/payments/presentation/pages/today_payments_page.dart:2508-2607` (`_GroupedCollectedList`)

**Interfaces:**
- Consumes: `List<TodayPayment> collected`, `bool isDark`, callbacks
- Produces: Updated grouping logic

- [ ] **Step 1: Modify `_GroupedCollectedList` grouping logic**

Replace the grouping logic at lines 2537-2541:

```dart
// BEFORE:
// Group by member
final Map<String, List<TodayPayment>> grouped = {};
for (final p in collected) {
  grouped.putIfAbsent(p.memberName, () => []).add(p);
}
```

With:

```dart
// AFTER:
// Group by member + type
final Map<String, List<TodayPayment>> grouped = {};
for (final p in collected) {
  final key = '${p.memberName}_${p.type.name}';
  grouped.putIfAbsent(key, () => []).add(p);
}
```

- [ ] **Step 2: Update the ListView.builder to use new grouping**

Replace lines 2546-2607:

```dart
return RefreshIndicator(
  onRefresh: onRefresh,
  color: AppColors.primary,
  child: ListView.builder(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
    itemCount: grouped.length,
    itemBuilder: (context, index) {
      final groupKey = grouped.keys.elementAt(index);
      final payments = grouped[groupKey]!;
      final totalCollected = payments.fold<double>(0, (sum, p) => sum + (p.amountCollected ?? p.amountExpected));
      final payment = payments.first;
      final memberName = payment.memberName;
      final typeLabel = payment.typeLabel;

      return _StaggeredFadeIn(
        index: index,
        child: GestureDetector(
          onTap: () => onTap(payment),
          child: GlassCard(
            glassmorphic: true,
            margin: const EdgeInsets.only(bottom: 10),
            borderRadius: 14,
            borderColor: AppColors.success.withValues(alpha: isDark ? 0.18 : 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _PaymentAvatar(
                  type: payment.type,
                  label: memberName,
                  color: AppColors.success,
                  isCollected: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$memberName • $typeLabel',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: -0.2,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0).format(totalCollected),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              letterSpacing: -0.4,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      // ... rest of the card content remains the same
```

- [ ] **Step 3: Run the app and verify changes**

Run: `flutter run`
Verify: Navigate to Admin > Payments > Done tab. Verify separate cards for EMI and Savings.

- [ ] **Step 4: Commit changes**

```bash
git add lib/features/payments/presentation/pages/today_payments_page.dart
git commit -m "feat: separate EMI and savings cards in admin payments Done tab"
```

---

## Task 4: Final Verification

**Covers:** End-to-end testing of all three views

**Files:**
- None (verification only)

- [ ] **Step 1: Test Staff View**

1. Run `flutter run`
2. Login as Staff user
3. Navigate to Payments tab
4. Switch to "Done" tab
5. Verify: Members with both EMI and Savings show as separate cards
6. Verify: Card shows "Member Name • EMI" or "Member Name • Savings"
7. Verify: Tap on card still opens payment details

- [ ] **Step 2: Test Branch Manager View**

1. Login as Branch Manager user
2. Navigate to Payments tab
3. Switch to "Done" tab
4. Verify: Same behavior as Staff view

- [ ] **Step 3: Test Admin View**

1. Login as Admin user
2. Navigate to Payments tab
3. Switch to "Done" tab
4. Verify: Same behavior as Staff view

- [ ] **Step 4: Test Edge Cases**

1. Verify: Members with only EMI show one card
2. Verify: Members with only Savings show one card
3. Verify: Members with both show two cards
4. Verify: Empty state still shows correctly
5. Verify: Refresh still works

- [ ] **Step 5: Final Commit (if needed)**

```bash
git add .
git commit -m "test: verify EMI/savings card separation across all views"
```

---

## Success Criteria

- [ ] Staff payments Done tab shows separate cards for EMI and Savings
- [ ] Branch Manager payments Done tab shows separate cards for EMI and Savings
- [ ] Admin payments Done tab shows separate cards for EMI and Savings
- [ ] Card display shows "Member Name • EMI" or "Member Name • Savings"
- [ ] All existing functionality (tap, refresh, animations) preserved
- [ ] No regressions in other tabs (Pending, Overdue)
