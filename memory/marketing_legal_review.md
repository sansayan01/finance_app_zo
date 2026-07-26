# Marketing Site Legal Pages — Review & Proposed Improvements

> **STATUS: DRAFT FOR LAWYER REVIEW.** Content below is legally-aware boilerplate written to align the
> marketing site (`marketing_site/app/(marketing)/privacy` and `/terms`) with the in-app legal content
> (`lib/features/settings/data/constants/legal_content.dart`) and India fintech compliance expectations.
> It is NOT legal advice. Have a qualified India advocate (DPDP / RBI / contract) review before publishing.
> Bracketed `[PLACEHOLDERS]` MUST be replaced with real values (entity name, emails, addresses, officer names).

**Reviewed files (read-only):**
- `marketing_site/app/(marketing)/privacy/page.tsx`
- `marketing_site/app/(marketing)/terms/page.tsx`
- `marketing_site/lib/site-config.ts`
- `marketing_site/app/(marketing)/contact/page.tsx`, `components/forms/ContactForm.tsx`, `app/actions/submit-lead.ts`
- `lib/features/settings/data/constants/legal_content.dart` (in-app baseline)

---

## 1. Current State

- **`/privacy`** — 6 thin sections (collect / use / security / rights / contact). Generic SaaS boilerplate.
  No India data law, no localisation, no retention schedule, no third-party sub-processors, no Grievance/DPO
  officer. "Contact" just points at the contact page (no address/email anywhere on the marketing site).
- **`/terms`** — 6 sections (acceptance / description / responsibilities / liability / changes / contact).
  Generic. No NBFC/technology-platform disclaimer, no collection-practices conduct clause, no GST/OIDAR note,
  no subscription/refund term, no termination/data-export window, no governing-law/jurisdiction.
- **`site-config.ts`** — footer `legal` only lists Privacy + Terms. No Refund Policy, Data Processing
  Addendum, or Grievance Redressal link. No contact email exposed to the pages.

---

## 2. Gaps Found (India compliance focused)

- [ ] **No DPDP Act 2023 reference** — India's digital personal-data law is absent on both pages.
- [ ] **No Data Protection Officer (DPO) / Grievance Redressal Officer** name + contact + 30-day
      acknowledgment commitment (DPDP Rules expectation).
- [ ] **No data localisation statement** — app stores on Supabase; Indian fintech buyers expect a
      "data hosted in India / Supabase Mumbai region" statement. Currently unmentioned.
- [ ] **No explicit borrower / end-customer consent language** — GPS tracking, automated SMS/WhatsApp
      recovery nudges, and financial-data processing need affirmative-consent wording.
- [ ] **No NBFC relationship disclaimer** — MicroFlow is a technology/SaaS platform, NOT an NBFC, lender,
      or payment aggregator. Must state this explicitly (RBI fair-practice exposure).
- [ ] **No collection-practices / recovery-agent conduct clause** — RBI guidelines: no calls before 7 AM /
      after 9 PM, max one visit per day, no harassment/coercion, no contact with third parties about debt.
- [ ] **No sub-processor list** — payment gateways (Razorpay/PhonePe/UPI), comms (SMS/WhatsApp/SMTP),
      cloud (Supabase/Google Drive) are named in the app policy but NOT on the marketing site.
- [ ] **No retention schedule** — app policy states 7-yr audit logs, 2-yr tickets, 30-day purge; marketing
      site says nothing.
- [ ] **No GST / OIDAR note** — SaaS sold to Indian MFIs attracts GST; cross-border OIDAR 18% may apply.
      Tax handling should be disclosed.
- [ ] **No governing law / jurisdiction** — should state Indian law, courts of [Kolkata/Delhi/…].
- [ ] **No subscription, refund, or termination/data-export term** on the marketing site (exists only in-app).
- [ ] **`Last updated` is "January 2026"** but in-app content says "July 2026" — dates are out of sync.
- [ ] **Footer legal nav missing** Refund Policy + DPA + Grievance Redressal links.
- [ ] **No cookie / tracking disclosure** (PostHog, analytics, marketing pixels) — required under DPDP
      transparency.

---

## 3. Proposed Improved Content — `privacy/page.tsx`

> Replace the `<div className="prose ...">` body. Keep the existing `metadata` + `Section`/`Container`
> shell. Re-date to `July 2026` to match the in-app policy. Use a real contact email where `[PRIVACY_EMAIL]`
> appears; add Grievance + DPO contacts.

```tsx
<div className="prose prose-slate mt-8 max-w-none dark:prose-invert">
  <p><strong>Last updated: July 2026</strong></p>
  <p className="text-text-muted">
    This Privacy Policy explains how MicroFlow Pro ("we", "us", "the platform") — a SaaS product of
    [LEGAL_ENTITY_NAME], India — collects, uses, stores, and protects personal and financial data when you
    visit this website, request a demo, or use the platform. This is a draft summary; the full, binding
    version lives in-app under <em>Settings → Legal</em>.
  </p>

  <h2>1. Who We Are (Data Fiduciary)</h2>
  <p>
    MicroFlow Pro is a <strong>technology platform</strong> for Micro-Finance Institutions (MFIs) and
    savings groups. We are a software service provider and are <strong>not</strong> a Non-Banking Financial
    Company (NBFC), bank, lender, payment aggregator, or financial advisor. We process data only as a
    Data Fiduciary / processor on behalf of the subscribing MFI, which remains accountable to its borrowers.
  </p>

  <h2>2. Information We Collect</h2>
  <p>We collect the following categories of data:</p>
  <ul>
    <li><strong>Website / lead data:</strong> name, email, organization name, role, country, MFI size, and
      message you submit via our contact and demo forms.</li>
    <li><strong>Organization data:</strong> legal name, display name, GST/PAN, address, and contact details.</li>
    <li><strong>User profiles:</strong> name, email, phone, role, and branch assignment of platform users.</li>
    <li><strong>Financial records:</strong> loan details, repayment schedules, savings plans, and
      transaction history entered by the MFI.</li>
    <li><strong>Field / location data:</strong> GPS coordinates captured during collection visits and
      check-in/out events (with user consent).</li>
    <li><strong>Device &amp; usage metadata:</strong> app version, device type, last-activity timestamps, and
      aggregated analytics cookies.</li>
    <li><strong>Support tickets:</strong> subject, description, and communication history.</li>
  </ul>

  <h2>3. Legal Basis &amp; Consent</h2>
  <p>We process personal data on the following bases under the <strong>Digital Personal Data Protection
    Act, 2023 (DPDP Act)</strong>:</p>
  <ul>
    <li><strong>Consent:</strong> for marketing communications, optional features, and location tracking.</li>
    <li><strong>Contractual necessity:</strong> to deliver the financial-management service the MFI subscribed to.</li>
    <li><strong>Legitimate interest:</strong> security monitoring, fraud prevention, and service improvement.</li>
    <li><strong>Legal obligation:</strong> audit logging and financial-record retention as required by law.</li>
  </ul>
  <p>
    Where we process data of end-borrowers (e.g. automated SMS/WhatsApp repayment reminders, GPS-verified
    visits), we rely on the subscribing MFI's lawful consent obtained at loan origination. You may withdraw
    consent for marketing at any time.
  </p>

  <h2>4. How We Use Your Information</h2>
  <ul>
    <li>Respond to inquiries, schedule demos, and provide customer support.</li>
    <li>Provide loan tracking, collections, savings, and analytics to the subscribing MFI.</li>
    <li>Send automated notifications (SMS, email, WhatsApp) for repayments and alerts.</li>
    <li>Verify field compliance through GPS-tagged visit records.</li>
    <li>Maintain audit logs and regulatory reporting.</li>
    <li>Improve the website and platform (aggregate, non-identifying analytics only).</li>
  </ul>

  <h2>5. Data Sharing &amp; Sub-Processors</h2>
  <p>We share data only with vetted sub-processors, and never sell or rent personal data:</p>
  <ul>
    <li><strong>Payment gateways:</strong> Razorpay, PhonePe, UPI — repayment processing.</li>
    <li><strong>Communication providers:</strong> SMS gateway, WhatsApp Business API, SMTP — notifications.</li>
    <li><strong>Cloud infrastructure:</strong> Supabase (data storage &amp; backups), Google Drive (optional
      export/backup).</li>
    <li><strong>Analytics:</strong> aggregate usage statistics with no personally identifiable information.</li>
  </ul>

  <h2>6. Data Localisation &amp; Security</h2>
  <p>
    Personal data of Indian users is hosted on infrastructure located in <strong>India (Supabase Mumbai
    region)</strong>. We apply:
  </p>
  <ul>
    <li>TLS 1.3 encryption in transit and encryption at rest for credentials and sensitive fields.</li>
    <li>Row-Level Security (RLS) enforcing role-based, multi-tenant data isolation.</li>
    <li>On-device encryption of offline data via platform keychain.</li>
    <li>Session timeouts, optional 2FA, and periodic security audits.</li>
  </ul>

  <h2>7. Data Retention</h2>
  <ul>
    <li>Active organization data: retained while the account is active.</li>
    <li>Audit logs: default 7 years (regulatory requirement).</li>
    <li>Support tickets: 2 years after resolution.</li>
    <li>Backups: per the configured retention schedule.</li>
    <li>Account deletion: all organization data purged within 30 days of a verified request.</li>
  </ul>

  <h2>8. Your Rights (DPDP Act, 2023)</h2>
  <p>As a data principal you may:</p>
  <ul>
    <li><strong>Access</strong> a copy of your data.</li>
    <li><strong>Rectify</strong> inaccurate personal data.</li>
    <li><strong>Erase</strong> data (subject to legal retention).</li>
    <li><strong>Port</strong> your data (JSON/CSV export).</li>
    <li><strong>Withdraw consent</strong> for marketing and optional processing.</li>
    <li><strong>Grievance redressal</strong> — contact details below.</li>
  </ul>

  <h2>9. Cookies &amp; Tracking</h2>
  <p>
    We use essential cookies for site function and analytics cookies (e.g. PostHog) to understand usage. You
    can disable non-essential cookies in your browser; this does not affect core functionality.
  </p>

  <h2>10. Grievance Redressal &amp; Data Protection Officer</h2>
  <ul>
    <li><strong>Grievance Redressal Officer:</strong> [OFFICER_NAME] — [GR_EMAIL] — [PHONE] — responses
      within 30 days as required under the DPDP Rules.</li>
    <li><strong>Data Protection Officer (DPO):</strong> [DPO_EMAIL].</li>
    <li><strong>General privacy queries:</strong> [PRIVACY_EMAIL].</li>
    <li><strong>Postal address:</strong> [REGISTERED_ADDRESS].</li>
  </ul>

  <h2>11. Changes</h2>
  <p>
    We may update this policy and will post the revised version here with a new "Last updated" date. Material
    changes will be notified to account administrators.
  </p>
</div>
```

---

## 4. Proposed Improved Content — `terms/page.tsx`

> Keep the existing `metadata` shell; replace the body. Re-date to `July 2026`.

```tsx
<div className="prose prose-slate mt-8 max-w-none dark:prose-invert">
  <p><strong>Last updated: July 2026</strong></p>

  <h2>1. Acceptance of Terms</h2>
  <p>
    By accessing or using MicroFlow Pro you agree to these Terms of Service. If you do not agree, do not use
    the service. These terms bind all users — Executive Admins, Branch Managers, Collection Agents, and
    End Customers.
  </p>

  <h2>2. Service Description</h2>
  <p>
    MicroFlow Pro is a multi-tenant SaaS platform for Micro-Finance Institutions providing field collections,
    branch management, loan/savings tracking, performance gamification, audit logging, and offline-first
    data capture with auto-sync. The service is provided "as is" and may be updated or discontinued with
    reasonable notice.
  </p>

  <h2>3. Not a Financial Institution (Important)</h2>
  <p>
    MicroFlow Pro is a <strong>technology platform only</strong>. We are <strong>not an NBFC, bank, lender,
    payment aggregator, or financial advisor</strong>, and we do not issue loans, guarantee repayment, hold
    customer funds, or provide investment advice. All lending, recovery, and customer relationships are the
    sole responsibility of the subscribing MFI, which must comply with applicable RBI and state regulations.
  </p>

  <h2>4. Fair Collection Practices (RBI Guidelines)</h2>
  <p>
    MFIs using MicroFlow Pro must conduct recoveries in line with RBI fair-practice / code-of-conduct
    guidelines. Agents may <strong>not</strong>:
  </p>
  <ul>
    <li>Call borrowers before 7:00 AM or after 9:00 PM local time.</li>
    <li>Visit a borrower's residence or workplace more than once per day.</li>
    <li>Use harassment, coercion, intimidation, or abusive language.</li>
    <li>Disclose a borrower's debt to third parties (employers, neighbours, family) beyond authorized
      co-obligants.</li>
    <li>Seize property without due legal process.</li>
  </ul>
  <p>The platform's activity logs are intended to evidence compliant conduct; misuse may lead to termination.</p>

  <h2>5. User Responsibilities</h2>
  <ul>
    <li>Keep account credentials confidential; you are liable for all activity under your account.</li>
    <li>Enter accurate, complete financial data.</li>
    <li>Comply with applicable financial and data-protection laws in your jurisdiction.</li>
    <li>Obtain lawful borrower consent before processing personal/financial data.</li>
    <li>Report vulnerabilities through proper channels; do not circumvent security.</li>
  </ul>

  <h2>6. Subscriptions, Fees &amp; Taxes</h2>
  <ul>
    <li>Fees are per the subscribed plan and billed in INR unless stated otherwise.</li>
    <li>Indian subscriptions attract <strong>GST</strong> at the applicable rate; cross-border OIDAR supplies
      may attract <strong>18% IGST</strong>. Tax is shown on invoices.</li>
    <li>Refunds follow our <a href="/refund-policy">Refund Policy</a>.</li>
  </ul>

  <h2>7. Limitation of Liability</h2>
  <p>
    To the maximum extent permitted by law, MicroFlow Pro is not liable for indirect, incidental, or
    consequential damages, and total liability is capped at subscription fees paid in the preceding 12
    months. We are not liable for force-majeure data loss or third-party interruptions (gateways, SMS).
    Organizations should maintain independent backups.
  </p>

  <h2>8. Termination &amp; Data Export</h2>
  <p>
    Either party may terminate. On termination, access ceases immediately and a data export is available for
    30 days, after which organization data is purged within 30 days. We may suspend accounts for terms
    violations with 30 days' notice to remediate.
  </p>

  <h2>9. Governing Law</h2>
  <p>
    These terms are governed by the laws of India. The courts at [JURISDICTION_CITY] have exclusive
    jurisdiction.
  </p>

  <h2>10. Changes &amp; Contact</h2>
  <p>
    We may update these terms and will post changes here. Questions: <a href="/contact">contact us</a> or
    email [LEGAL_EMAIL]. Grievances: see our <a href="/privacy">Privacy Policy</a>.
  </p>
</div>
```

---

## 5. Specific Change List

**`privacy/page.tsx`**
- Re-date `Last updated` → `July 2026` (sync with in-app "July 2026").
- Add §1 "Who We Are (Data Fiduciary)" + explicit **NBFC/non-lender disclaimer**.
- Expand "Information We Collect" to all 7 categories (org, user, financial, GPS/location, device, tickets, website/lead).
- Add **§3 Legal Basis & Consent** referencing DPDP Act 2023 + borrower consent for GPS/SMS/WhatsApp.
- Add **§5 Sub-Processors** (Razorpay, PhonePe, UPI, SMS/WhatsApp/SMTP, Supabase, Google Drive).
- Add **§6 Data Localisation** — Supabase Mumbai / India region; TLS 1.3, RLS, on-device encryption.
- Add **§7 Retention schedule** (7-yr audit, 2-yr tickets, 30-day purge).
- Add **§9 Cookies & Tracking** (PostHog/analytics disclosure).
- Add **§10 Grievance Redressal Officer + DPO + postal address** with [PLACEHOLDERS].

**`terms/page.tsx`**
- Re-date → `July 2026`.
- Add **§3 Not a Financial Institution** (not NBFC/bank/lender/aggregator/advisor).
- Add **§4 Fair Collection Practices** (RBI: no calls 7AM–9PM, max 1 visit/day, no harassment, no third-party disclosure).
- Add **§6 Subscriptions, Fees & GST/OIDAR 18%** note.
- Add **§8 Termination & 30-day data-export window**.
- Add **§9 Governing Law / Indian jurisdiction**.
- Link Refund Policy + Privacy where referenced.

**`lib/site-config.ts`** (footer `legal`)
- Add entries: `Refund Policy → /refund-policy`, `Data Processing Addendum → /dpa` (optional),
  `Grievance Redressal → /grievance` (optional). Currently only Privacy + Terms.

**New pages to consider (out of scope but flagged)**
- `/refund-policy` (content exists in-app `kRefundPolicySections`; not yet on marketing site).
- `/dpa` Data Processing Addendum (exists in-app `kDataProcessingSections`).
- `/grievance` standalone redressal page (RBI/DPDP expectation).

**Cross-cutting**
- No contact email exists anywhere on the marketing site (all "Contact" links go to `/contact` form).
  Proposed content introduces `[PRIVACY_EMAIL]`, `[LEGAL_EMAIL]`, `[GR_EMAIL]`, `[DPO_EMAIL]` placeholders
  that must be wired into `site-config.ts` or a new `lib/contacts.ts` constant.
- Bump both pages' `description` metadata to mention India/DPDP for SEO + transparency.

---

## Placeholder Checklist (replace before publish)
- [ ] `LEGAL_ENTITY_NAME` — the registered company operating MicroFlow Pro
- [ ] `REGISTERED_ADDRESS`
- [ ] `PRIVACY_EMAIL`, `LEGAL_EMAIL`, `GR_EMAIL`, `DPO_EMAIL`
- [ ] `OFFICER_NAME` (Grievance Redressal Officer) + `PHONE`
- [ ] `JURISDICTION_CITY` (governing-law courts)
- [ ] Confirm Supabase region is actually Mumbai/India; adjust wording if not
- [ ] Lawyer review of DPDP/RBI clauses + GST/OIDAR applicability
