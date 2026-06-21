# Customer Quick Pay — Bulk UPI Installment Payments

**Goal:** Let customers select and pay multiple pending installments (EMI or savings) in a single UPI transaction, instead of paying one at a time.

**Architecture:** Per-loan/per-savings quick pay pages that reuse the staff's `EmiPaymentSelector`/`SavingsPaymentSelector` counter and calendar patterns. Single UPI payment → multiple `upi_payment_request` rows → staff confirms per-row → `collections` records created with customer's payment time.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase, existing `upi://pay` deep links

---

## User Flow

1. Customer opens a specific loan or savings detail page
2. Taps "Pay via UPI" button (existing)
3. **Quick Pay page opens** (NEW) showing that loan/savings plan's pending installments
4. Customer chooses installments via:
   - **Counter mode (+/-)**: auto-allocates overdue → today → advance
   - **Calendar mode**: taps specific dates (calendar opens immediately)
5. Taps "Pay ₹X via UPI"
6. UPI sheet opens with combined amount, QR code, and auto-filled transaction notes
7. Customer pays in UPI app, taps "I've Paid"
8. One `upi_payment_request` row per selected installment is created
9. Staff/admin sees grouped batch on UPI Confirmations page
10. Staff confirms → `collections` records created with `collection_date` = customer's `created_at` (not confirmation time)

---

## New Files

### 1. Customer Loan Quick Pay Page
**Path:** `lib/features/customer_portal/presentation/pages/customer_loan_quick_pay_page.dart`

- **Route:** `/customer/loan/:loanId/quick-pay`
- **Widget:** `CustomerLoanQuickPayPage` — `ConsumerStatefulWidget`
- **Params:** `loanId` (required)
- **Header:** Shows loan number, EMI amount, count of remaining installments
- **Body:** Two tabs via `TabBar`:
  - **Quick Pay tab** (⚡): Reuses `EmiPaymentSelector` in counter mode
  - **Choose Dates tab** (📅): Reuses `EmiPaymentSelector` in calendar mode — calendar opens immediately on tab switch
- **Bottom bar:** `Selected: N · ₹X` + "Pay via UPI" button (disabled when nothing selected)
- **On tap "Pay":** Opens modified `UpiPaymentSheet` with the batch of selected EMIs

### 2. Customer Savings Quick Pay Page
**Path:** `lib/features/customer_portal/presentation/pages/customer_savings_quick_pay_page.dart`

- **Route:** `/customer/savings/:savingsId/quick-pay`
- **Widget:** `CustomerSavingsQuickPayPage` — `ConsumerStatefulWidget`
- **Params:** `savingsPlanId` (required)
- **Header:** Shows savings plan name, installment amount, count of pending installments
- **Body:** Same two-tab layout as loan version, uses `SavingsPaymentSelector`
- **Bottom bar:** Same as loan version
- **On tap "Pay":** Opens modified `UpiPaymentSheet` with the batch of selected savings installments

---

## Modified Files

### 3. `UpiPaymentSheet` — Support Batch Payments
**Path:** `lib/features/payments/presentation/widgets/upi_payment_sheet.dart`

**Changes:**
- Add new optional parameters: `List<String>? emiScheduleIds`, `List<String>? savingsInstallmentDates`, `String? transactionNoteOverride`
- When `emiScheduleIds` is provided (batch mode):
  - Combined amount shown in QR/UPI URI
  - Transaction note uses batch format: `"Loan #001 · EMI #4,5,6 · ₹6,000"`
  - On "I've Paid": loops through each `emiScheduleId` and creates a separate `upi_payment_request` row
- When single installment (current behavior): unchanged

### 4. `UpiService.buildUpiUri()` — Batch Transaction Notes
**Path:** `lib/features/payments/data/services/upi_service.dart`

**Changes:**
- No structural change needed — the `transactionNote` parameter already accepts any string
- The calling code (UpiPaymentSheet) will construct the batch note before passing it

### 5. `UpiPaymentRepository.createRequest()` — No Change
Already handles single-row inserts. The batch loop lives in the UPI sheet, calling `createRequest()` once per installment.

### 6. Customer Loan Detail Page — Redirect to Quick Pay
**Path:** `lib/features/customer_portal/presentation/pages/customer_loan_detail_page.dart`

**Changes:**
- Existing "Pay via UPI" button now opens `CustomerLoanQuickPayPage` instead of `UpiPaymentSheet` directly
- Route: navigate to `/customer/loan/:loanId/quick-pay`

### 7. Customer Savings Detail Page — Redirect to Quick Pay
**Path:** `lib/features/customer_portal/presentation/pages/customer_savings_detail_page.dart`

**Changes:**
- Existing "Pay via UPI" button now opens `CustomerSavingsQuickPayPage` instead of `UpiPaymentSheet` directly
- Route: navigate to `/customer/savings/:savingsId/quick-pay`

### 8. Customer EMI Schedule Page — Redirect to Quick Pay
**Path:** `lib/features/customer_portal/presentation/pages/customer_emi_schedule_page.dart`

**Changes:**
- Existing "Pay via UPI" button in header now navigates to the quick pay page for that loan
- Route: navigate to `/customer/loan/:loanId/quick-pay`

### 9. UPI Confirmations Page — Batch Grouping
**Path:** `lib/features/payments/presentation/pages/upi_confirmations_page.dart`

**Changes:**
- Group requests by `customer_id` + `loan_id` (or `savings_plan_id`) + `created_at` within 5 minutes
- Each group renders as a collapsible card with batch summary
- Per-request checkboxes within each batch
- "Select All" per batch
- "Confirm Selected" confirms checked requests → creates `collections` records using `created_at` as `collection_date`
- "Reject" opens reason dialog for checked requests

### 10. App Router — Add Quick Pay Routes
**Path:** `lib/router/app_router.dart`

**Changes:**
- Add routes under `CustomerShell`:
  - `/customer/loan/:loanId/quick-pay` → `CustomerLoanQuickPayPage`
  - `/customer/savings/:savingsId/quick-pay` → `CustomerSavingsQuickPayPage`

---

## Data Flow: Batch Payment → Staff Confirmation → Collection

### Step 1: Customer taps "I've Paid" (3 EMIs selected)

```
upi_payment_requests table:
  row 1: { customer_id: 'rahul', loan_id: 'loan-001', emi_schedule_id: 'emi-4', amount: 2000, status: 'pending', created_at: '2026-06-21T14:32:00Z' }
  row 2: { customer_id: 'rahul', loan_id: 'loan-001', emi_schedule_id: 'emi-5', amount: 2000, status: 'pending', created_at: '2026-06-21T14:32:00Z' }
  row 3: { customer_id: 'rahul', loan_id: 'loan-001', emi_schedule_id: 'emi-6', amount: 2000, status: 'pending', created_at: '2026-06-21T14:32:00Z' }
```

### Step 2: Staff confirms all 3

```
upi_payment_requests table (updated):
  row 1: { status: 'confirmed', confirmed_by: 'priya-id', confirmed_at: '2026-06-21T18:15:00Z' }
  row 2: { status: 'confirmed', confirmed_by: 'priya-id', confirmed_at: '2026-06-21T18:15:00Z' }
  row 3: { status: 'confirmed', confirmed_by: 'priya-id', confirmed_at: '2026-06-21T18:15:00Z' }

collections table (new rows — 1 per EMI):
  row 1: { loan_id: 'loan-001', member_id: 'rahul-member', staff_id: 'priya-id', amount_collected: 2000, payment_mode: 'upi', collection_date: '2026-06-21' }
  row 2: { loan_id: 'loan-001', member_id: 'rahul-member', staff_id: 'priya-id', amount_collected: 2000, payment_mode: 'upi', collection_date: '2026-06-21' }
  row 3: { loan_id: 'loan-001', member_id: 'rahul-member', staff_id: 'priya-id', amount_collected: 2000, payment_mode: 'upi', collection_date: '2026-06-21' }
```

**Key:** `collection_date` uses the customer's payment time (`created_at` = `2026-06-21`), NOT the staff confirmation time (`confirmed_at` = `2026-06-21T18:15:00Z`).

### Step 3: DB trigger runs automatically

`update_schedule_on_collection_v2()` fires for each `collections` insert:
- Marks EMI #4, #5, #6 as **paid** in `emi_schedule`
- Updates `loans.outstanding_amount`

### Step 4: Customer sees confirmation

- Loan detail page shows updated EMI statuses
- Transaction history shows "Paid via UPI, confirmed by Priya"

---

## Batch Grouping Logic (Staff Side)

Requests are grouped into a batch when:
- Same `customer_id`
- Same `loan_id` (or `savings_plan_id`)
- `created_at` within 5 minutes of each other

This handles the case where a customer pays, then immediately pays again — staff sees two separate batches.

---

## Edge Cases

1. **Customer selects 0 items:** "Pay" button disabled, cannot proceed
2. **Customer closes app after UPI payment but before "I've Paid":** Pending request not created. Customer can retry from the quick pay page (existing `checkExistingPending` prevents duplicates)
3. **Staff rejects a batch:** Each rejected row gets `rejection_reason`. Customer sees rejection on their UPI request history
4. **Partial confirmation:** Staff can uncheck some EMIs and confirm only selected ones. Rejected EMIs remain pending for next payment attempt
5. **Mix of overdue + advance:** Counter mode auto-allocates oldest-first (overdue → today → advance). Calendar mode lets customer pick any dates.

---

## Testing Strategy

1. **Unit tests:** `UpiService.buildUpiUri()` with batch note text
2. **Widget tests:** `CustomerLoanQuickPayPage` counter selection, calendar selection, total calculation
3. **Widget tests:** `UpiPaymentSheet` batch mode (multiple `createRequest` calls)
4. **Integration test:** Full flow — select EMIs → pay → verify `upi_payment_requests` rows created with correct `emi_schedule_id` values
