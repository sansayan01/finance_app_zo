# UPI Payment Feature — Design Spec

**Date:** 2026-06-21
**Status:** Draft (pending user spec review)
**Author:** Claude (brainstorming → spec)
**Scope:** Customer-initiated UPI payments for loan EMIs and savings installments

---

## Problem

Customers currently have no way to self-serve their payments. All collections must be done by staff in person, which limits flexibility and adds friction. Customers want to pay their loan EMIs and savings installments from their phone at their convenience — but the app has no payment gateway, and the org needs a simple, low-cost way to accept UPI payments.

## Solution

Use UPI deep links (`upi://pay?pa=...&am=...`) to let customers open their installed UPI app (Google Pay, PhonePe, Paytm, etc.) with the payment details pre-filled. The customer only enters their UPI PIN to complete the payment. A QR code is also generated for in-person scenarios. A pending payment is staged in the database, then confirmed by staff, admin, or branch manager through their portals.

## Goals (in scope)

- Store org-level UPI VPA in the existing `organizations.settings` JSONB column (no migration for config).
- Add a `upi_payment_requests` table to stage pending payments before staff confirmation.
- Customer can tap "Pay via UPI" on any unpaid EMI or savings installment.
- App opens native UPI intent with amount and VPA pre-filled.
- QR code is generated encoding the same UPI intent URI (for in-person scenarios).
- Customer taps "I've Paid" after completing payment → creates a pending payment request.
- Staff / admin / branch manager can view and confirm pending UPI payments.
- On confirmation → standard `collections` record is created → triggers existing EMI/savings update logic.
- Rejection flow with mandatory reason.

## Non-goals (out of scope, flagged for roadmap)

- Payment gateway integration (Razorpay, PhonePe, Cashfree) — future enhancement.
- Automatic payment verification via webhooks/callbacks.
- UPI Reference Number (UTR) verification — can be added later.
- Customer self-service receipt generation for UPI payments (will reuse existing receipt flow after confirmation).
- Multi-VPA / per-staff VPA support.
- Real-time payment status polling.

---

## Architecture

### Data Model

#### UPI Configuration Storage

No new table. Stored in `organizations.settings` JSONB under a `payment` key:

```json
{
  "payment": {
    "upi_vpa": "merchant@upi",
    "merchant_name": "My Finance Org"
  }
}
```

This follows the existing pattern for `profile`, `branding`, and `compliance` keys — zero migration needed for config.

#### New Table: `upi_payment_requests`

```sql
create table upi_payment_requests (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organizations(id),
  customer_id   uuid not null references auth.users(id),
  loan_id       uuid references loans(id),
  savings_plan_id uuid references savings_plans(id),
  emi_schedule_id uuid references emi_schedule(id),
  amount        numeric(12,2) not null,
  upi_vpa       text not null,
  transaction_ref text,
  status        text not null default 'pending'
                check (status in ('pending', 'confirmed', 'rejected')),
  confirmed_by  uuid references auth.users(id),
  confirmed_at  timestamptz,
  rejection_reason text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Indexes
create index upi_payment_requests_org_status_idx on upi_payment_requests (org_id, status);
create index upi_payment_requests_customer_idx on upi_payment_requests (customer_id, created_at desc);

-- RLS: customer can see their own, staff/admin/manager can see org-wide
alter table upi_payment_requests enable row level security;

create policy "Customers view own UPI requests"
  on upi_payment_requests for select
  using (auth.uid() = customer_id);

create policy "Staff/admin/manager view org UPI requests"
  on upi_payment_requests for select
  using (
    org_id in (
      select org_id from user_org_roles
      where user_id = auth.uid()
      and role in ('admin', 'staff', 'branch_manager')
    )
  );

create policy "Customers create UPI requests"
  on upi_payment_requests for insert
  with check (auth.uid() = customer_id);

create policy "Staff/admin/manager update UPI requests"
  on upi_payment_requests for update
  using (
    org_id in (
      select org_id from user_org_roles
      where user_id = auth.uid()
      and role in ('admin', 'staff', 'branch_manager')
    )
  );
```

#### Status Flow

```
pending → confirmed (by staff/admin/branch manager)
pending → rejected (with reason)
```

When confirmed: creates a standard `collections` record → triggers existing `update_schedule_on_collection_v2()` → EMI status, loan balance, savings installments all update normally.

### UPI Intent URI

```
upi://pay?pa={vpa}&am={amount}&pn={merchant_name}&tn={transaction_note}&cu=INR
```

Example:
```
upi://pay?pa=myorg@upi&am=2500.00&pn=My%20Finance%20Org&tn=Loan%23123-EMI%235&cu=INR
```

The `url_launcher` package (already a dependency) opens the UPI app. `QrPng` service encodes the same URI as a QR code.

### Component Map

**Flutter (Dart)**
- `UpiConfigService` (new) — reads/writes org UPI config from `organizations.settings.payment`.
- `UpiPaymentService` (new) — creates `upi_payment_requests` records, launches UPI intent.
- `UpiPaymentConfirmService` (new) — confirms/rejects pending payments, creates `collections` records, triggers existing collection flow.
- `upi_config_section.dart` (new widget) — reusable UPI config form for Organization Settings.
- `customer_upi_payment_sheet.dart` (new bottom sheet) — shows QR code + "Open UPI App" button + "I've Paid" button.
- `upi_confirmations_page.dart` (new page) — lists pending UPI payments for staff/admin/manager to confirm.
- `upi_payment_request_model.dart` (new model) — data class for `upi_payment_requests` table.

**Supabase**
- Migration `2026-06-21_upi_payment_requests.sql` — creates the `upi_payment_requests` table with RLS policies.

### Data Flow — Customer Payment

```
[Customer EMI/Savings Detail Page]
  └─ Customer taps "Pay via UPI"
       └─ UpiPaymentService.getOrgVpa(orgId)
            └─ Query organizations.settings -> payment.upi_vpa
                 └─ No VPA? → Toast: "UPI not configured. Contact branch."
                 └─ Has VPA? → Show CustomerUpiPaymentSheet
                      ├─ QR code (QrPng.encode(upiUri))
                      ├─ "Open UPI App" button
                      │    └─ url_launcher.launch("upi://pay?pa=...&am=...")
                      └─ "I've Paid" button
                           └─ UpiPaymentService.createRequest({
                                orgId, customerId, loanId?, savingsPlanId?,
                                emiScheduleId?, amount, upiVpa
                              })
                                └─ Insert into upi_payment_requests (status=pending)
                                     └─ Toast: "Payment submitted for verification"
                                     └─ Invalidate EMI/Savings providers
```

### Data Flow — Staff Confirmation

```
[Staff/Admin/Branch Manager Dashboard]
  └─ Navigate to UPI Confirmations page
       └─ Query upi_payment_requests where org_id=org AND status=pending
            └─ List shows: customer name, type (loan/savings), amount, timestamp
                 ├─ Confirm button
                 │    └─ UpiPaymentConfirmService.confirm(request)
                 │         ├─ Create collections record (payment_mode=upi)
                 │         ├─ Call existing update_schedule_on_collection_v2 trigger
                 │         ├─ Update upi_payment_requests set status=confirmed, confirmed_by, confirmed_at
                 │         ├─ Dispatch SMS notification
                 │         └─ Invalidate providers
                 └─ Reject button
                      └─ Show rejection reason dialog
                           └─ Update upi_payment_requests set status=rejected, rejection_reason
                                └─ Toast: "Payment rejected"
```

---

## UI Design

### Organization Settings — Payment Configuration

Add a new section to `organization_settings_page.dart`:

```
┌─────────────────────────────────────┐
│  💳 Payment Configuration           │
│                                      │
│  UPI VPA (Virtual Payment Address)  │
│  ┌─────────────────────────────────┐│
│  │ merchant@upi                    ││
│  └─────────────────────────────────┘│
│  Format: name@bank (e.g. abc@upi)  │
│                                      │
│  Merchant Display Name               │
│  ┌─────────────────────────────────┐│
│  │ My Finance Organization         ││
│  └─────────────────────────────────┘│
│  Shown in UPI apps during payment   │
│                                      │
│  [Save Payment Settings]            │
└─────────────────────────────────────┘
```

### Customer Portal — UPI Payment Bottom Sheet

Shows when customer taps "Pay via UPI" on an EMI or savings installment:

```
┌─────────────────────────────────────┐
│  Pay via UPI                         │
│                                      │
│  ┌─────────────────────────────────┐│
│  │        [QR Code]                ││
│  │   Scan to pay ₹2,500.00        ││
│  │                                 ││
│  │  VPA: myorg@upi                ││
│  │  Ref: Loan #123 — EMI #5      ││
│  └─────────────────────────────────┘│
│                                      │
│  ┌─────────────────────────────────┐│
│  │     Open UPI App                ││
│  └─────────────────────────────────┘│
│                                      │
│  After payment, tap below:           │
│                                      │
│  ┌─────────────────────────────────┐│
│  │     I've Paid                   ││
│  └─────────────────────────────────┘│
│                                      │
└─────────────────────────────────────┘
```

### Staff/Admin — UPI Confirmations Page

```
┌─────────────────────────────────────┐
│  📱 UPI Payment Confirmations       │
│  ───────────────────────────────    │
│  [All] [Pending (3)] [Confirmed]   │
│                                      │
│  ┌─────────────────────────────────┐│
│  │ 🔵 Ramesh Kumar                 ││
│  │ Loan #123 — EMI #5              ││
│  │ ₹2,500.00                       ││
│  │ 2 mins ago                       ││
│  │                                 ││
│  │  [✅ Confirm]  [❌ Reject]      ││
│  └─────────────────────────────────┘│
│                                      │
│  ┌─────────────────────────────────┐│
│  │ 🔵 Priya Devi                   ││
│  │ Savings #45 — Inst. #3          ││
│  │ ₹1,000.00                       ││
│  │ 15 mins ago                      ││
│  │                                 ││
│  │  [✅ Confirm]  [❌ Reject]      ││
│  └─────────────────────────────────┘│
│                                      │
│  (empty state: "No pending UPI      │
│   payments")                         │
└─────────────────────────────────────┘
```

---

## Error Handling

| Failure | Detection | User-visible | Recovery |
|---|---|---|---|
| No VPA configured | `organizations.settings.payment.upi_vpa` is null | Toast: "UPI payments not available. Contact your branch." | Admin sets VPA in Org Settings |
| UPI app not installed | `url_launcher` returns `canLaunchUrl = false` | Dialog: "No UPI app found. Please install Google Pay, PhonePe, or Paytm." | Install UPI app |
| Customer taps "I've Paid" without paying | Staff rejects the payment | Rejection with reason | Customer can re-pay or contact staff |
| Database insert fails | Supabase error | Toast: "Something went wrong. Please try again." | Retry |
| Already pending payment exists | Query check before creating new request | Toast: "A payment is already pending for this installment" | Wait for staff to confirm/reject existing |
| Amount mismatch (partial payment) | Not handled in V1 — full EMI/installment amount only | Payment always uses full amount | Future: support partial UPI payments |
| Confirmation fails (collection trigger error) | Trigger throws | Toast for staff: "Confirmation failed. Check the collection data." | Manual collection |

---

## Testing

### Unit tests

- `UpiConfigService`: read/write VPA from JSONB settings.
- `UpiPaymentService`: URI generation, request creation, validation.
- `UpiPaymentConfirmService`: confirmation flow, collection record creation, rejection.
- UPI URI encoding: special characters in merchant name, amount precision, transaction note length.
- VPA format validation (basic `*@*` pattern).

### Integration tests

1. **Happy path (loan):** Customer taps Pay → UPI opens → customer pays → taps "I've Paid" → pending request created → staff confirms → EMI marked paid → loan balance updated.
2. **Happy path (savings):** Same flow for savings installment.
3. **Rejection:** Staff rejects with reason → customer sees rejection.
4. **No VPA:** Org has no UPI configured → customer sees "contact branch" message.
5. **Duplicate prevention:** Customer tries to pay an already-pending installment → blocked.
6. **QR code generation:** QR encodes correct UPI URI with amount and VPA.

### Manual smoke

- Org Settings: save and load UPI VPA and merchant name.
- Customer EMI page: "Pay via UPI" button appears for unpaid EMIs.
- QR code renders correctly with correct data.
- UPI app opens with correct amount and VPA.
- Staff confirmation page loads and filters work.
- Confirmed payment creates correct `collections` record.

---

## Files

### New

- `lib/features/payments/data/models/upi_payment_request_model.dart` — data class for `upi_payment_requests` table.
- `lib/features/payments/data/services/upi_config_service.dart` — reads/writes org UPI config from JSONB.
- `lib/features/payments/data/services/upi_payment_service.dart` — creates payment requests, launches UPI intent.
- `lib/features/payments/data/services/upi_confirm_service.dart` — confirms/rejects payments, creates collections records.
- `lib/features/payments/data/providers/upi_providers.dart` — Riverpod providers for UPI payment requests.
- `lib/features/payments/presentation/pages/upi_confirmations_page.dart` — staff/admin/manager confirmation page.
- `lib/features/payments/presentation/widgets/upi_payment_sheet.dart` — customer-facing payment bottom sheet with QR + buttons.
- `lib/features/payments/presentation/widgets/upi_config_section.dart` — reusable UPI config form widget.
- `test/features/payments/data/services/upi_payment_service_test.dart` — unit tests.
- `test/features/payments/data/services/upi_confirm_service_test.dart` — unit tests.
- `supabase/migrations/2026-06-21_upi_payment_requests.sql` — creates the `upi_payment_requests` table with RLS.

### Modified

- `lib/features/settings/presentation/pages/organization_settings_page.dart` — add Payment Configuration section (UPI VPA + merchant name fields).
- `lib/features/customer_portal/presentation/pages/customer_emi_schedule_page.dart` — add "Pay via UPI" button for unpaid EMIs.
- `lib/features/customer_portal/presentation/pages/customer_loan_detail_page.dart` — add "Pay via UPI" button for upcoming EMIs.
- `lib/features/customer_portal/presentation/pages/customer_savings_detail_page.dart` — add "Pay via UPI" button for savings installments.
- `lib/features/staff/presentation/pages/staff_dashboard_page.dart` — add "UPI Confirmations" card/link.
- `lib/features/settings/presentation/pages/integrations_settings_page.dart` — update UPI Organization Hook from P2 to Implemented.
- `lib/core/constants/enums.dart` — add `UpiPaymentStatus` enum.
- `lib/core/routes/app_router.dart` — add route for UPI confirmations page.

### Unchanged (but worth knowing)

- `lib/features/loans/data/services/qr_png.dart` — reused for QR generation, no changes needed.
- `supabase_schema.sql` — migration is additive; main schema unchanged.
- Existing collection flow (`collection_sheet.dart`, `collection_form_page.dart`) — unchanged, reuse via trigger.

---

## Risks

- **No automatic payment verification.** Staff must manually confirm. A dishonest customer could tap "I've Paid" without paying. Mitigation: staff can check their bank app, and rejection flow exists.
- **UPI app deep linking inconsistency.** Some Android devices handle `upi://pay` differently. We use `url_launcher` which abstracts this, but edge cases exist on some Chinese Android skins. Mitigation: fallback to showing QR code if intent fails.
- **QR code scanning from same device.** If customer is paying for themselves, the QR is on their own screen — they'd need another device to scan. Mitigation: the primary flow is "Open UPI App" button, QR is for in-person scenarios.
- **RLS policies.** The `user_org_roles` table join assumes a specific schema. If the org membership table has a different name/structure, the RLS policies need adjustment. Will verify during implementation.

---

## Acceptance criteria

1. Admin can set and save a UPI VPA and merchant name in Organization Settings.
2. Customer sees "Pay via UPI" button on unpaid EMIs and savings installments.
3. Tapping "Pay via UPI" shows a QR code and "Open UPI App" button with correct amount/VPA.
4. UPI app opens with amount and VPA pre-filled.
5. Customer can tap "I've Paid" to create a pending payment request.
6. Staff/admin/branch manager can view pending UPI payments on a dedicated page.
7. Staff can confirm a payment → standard collection is recorded → EMI/savings status updates.
8. Staff can reject a payment with a mandatory reason.
9. No duplicate payment requests for the same installment while one is pending.
10. "UPI not available" message shown when VPA is not configured.

---

## Next step

Spec self-review, then user review, then `superpowers:writing-plans` to produce an implementation plan.
