# MicroFlow Pro — India Fintech Compliance GAPS (Code-Level Scan)

Scanned Flutter source under `lib/` across 8 areas. NOTE: `legal_content.dart` and
`statement_org_info.dart` contain policy *text* and optional regulatory *fields*, but the
app flow does NOT enforce the underlying obligations at runtime.

## 1. Consent Capture
- Member/borrower: `member_onboarding_page.dart` collects name, phone, business, **GPS**
  (`captureLocation()` L209-219) and a photo placeholder with NO consent step.
  `onboarding_provider.submit()` (L83) writes the member immediately. `MemberModel` has no
  `consent`/`consent_timestamp` field. — GAP: no recorded borrower consent. LAUNCH-BLOCKING.
- Customer portal: `customer_profile_page.dart`, `customer_account_settings_page.dart` — no
  consent capture. Only org-side signup has a ToS checkbox (`signup_page.dart:310-343`), which
  is the *admin* agreeing, not the individual borrower. — LAUNCH-BLOCKING.
- SMS opt-in: `MemberModel.smsEnabled = true` default (`member_model.dart:35`), no opt-in
  prompt. — SHOULD-FIX (TRAI/DLT).

## 2. GPS / Location Collection
- Borrower GPS at onboarding: `member_onboarding_page.dart:209` writes `gps_lat/gps_lng` with
  no disclosure/consent. — LAUNCH-BLOCKING.
- Agent background tracking: `live_tracking_toggle.dart`, `staff_home_page._maybePromptTracking()`
  (L36), `background_location_service.dart` — OS permission only, no in-app purpose/retention disclosure. — SHOULD-FIX.
- Visit check-in: `visit_checkin_page.dart:44` auto-grabs position in `initState`, no consent gate. — SHOULD-FIX.

## 3. Collection / Recovery Agent Conduct
- No time-of-day restriction, no visit/contact frequency caps, no harassment guardrails anywhere.
  Grep across `collections/` shows "time" only in `collection_backdate_audit_repository.dart`
  (audit formatting, not enforcement). — GAP: RBI Fair Practices / DPNB 7 AM–7 PM windows,
  holiday blocks, frequency limits all absent. LAUNCH-BLOCKING.
- SMS escalation template (`sms_templates.dart:43-46`) has no sending-layer hour guard. — SHOULD-FIX.

## 4. Data Retention / Deletion
- Customer-side erasure: `customer_account_settings_page.dart` + `customer_profile_page.dart`
  have NO delete/close/deactivate (grep: no matches). Only links to external Terms/Privacy URLs.
  — GAP: DPDP right-to-erasure + RBI closure not provided in-app. LAUNCH-BLOCKING.
- Org-side purge: `legal_content.dart:79` claims 30-day purge but no code path implements
  borrower-data deletion (only backup/export exists). — SHOULD-FIX.
- `audit_retention_page.dart` configures audit-log retention only, not PII. — SHOULD-FIX.

## 5. Grievance / DPO
- `StatementOrgInfo.grievanceOfficer/grievancePhone` (`statement_org_info.dart:28-31`) is
  **optional** and only printed on PDF statements; org can leave null. No in-app grievance UI
  surfacing officer + escalation. — SHOULD-FIX.
- `customer_support_page.dart` (tickets) + `customer_feedback_page.dart` ("Complaint") exist,
  but no dedicated grievance redressal with RBI/NBFC escalation tier, no DPO contact, no SLA. — SHOULD-FIX.
- No DPO contact anywhere in `lib/`. — SHOULD-FIX.

## 6. Audit Logging
- STRENGTH: `audit_log_model.dart` (staffId, action, entityType, entityId, gps, ip, userAgent)
  + `AuditAction` enum + `activity_log_*` repos + `activity_logs_page.dart`/`user_audit_page.dart`
  + backdated-collection audit (`collection_backdate_audit_repository.dart`). Staff/agent actions
  are logged. — OK (partial).
- Gap: logs are staff-centric; no borrower-PII *access/export* trace from customer portal/admin. — LATER.

## 7. NBFC / RBI Verification
- `organization_profile_page.dart:331` + `organization_settings_page.dart:412` capture
  `registrationNumber` (free-text, **optional, unvalidated**), printed on statements. Onboarding
  does not require/verify it. — GAP: no RBI registry validation, no "verified NBFC" gate. SHOULD-FIX.

## 8. KYC
- `core/utils/kyc_validators.dart` — regex format checks for PAN (L8) / Aadhaar (L19) + masking
  only. `MemberModel.kycStatus` pending/verified/rejected; onboarding sets `pending`. — GAP: format
  validation only, no OVD/Aadhaar eKYC/DigiLocker/VKYC capture or verification. LAUNCH-BLOCKING.
- "Capture Shop Photo" is a placeholder (`member_onboarding_page.dart:224`);
  `customer_biometric_service.dart` is device *unlock* only; no Aadhaar/DigiLocker/eKYC integration. — LAUNCH-BLOCKING.
- `member_model.dart` doesn't even store the PAN/Aadhaar values the validators check — no secure KYC storage. — LAUNCH-BLOCKING.

## Biggest Gaps (summary)
1. No consent capture for borrowers (GPS, photos, SMS, PII collected with zero recorded consent) — DPDP + RBI violation.
2. Zero recovery-agent conduct guardrails (no 7AM–7PM window, no visit/contact caps, no harassment controls).
3. KYC is format-check-only — no Aadhaar eKYC/DigiLocker/OVD capture or verification workflow, no secure storage.
4. No erasure / grievance / DPO path for borrowers in customer portal.

NOTE: These are CODE-level gaps. The legal *text* in legal_content.dart + marketing pages is being
improved separately (see app_legal_review.md + marketing_legal_review.md). Filling the text without
enforcing the behaviour in code does NOT achieve compliance.
