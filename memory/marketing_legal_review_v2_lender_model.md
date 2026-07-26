# Marketing Legal Pages — Rewritten for the Individual-Lender / Book-Keeping Model

**Status:** DRAFT — pending lawyer review
**Date:** 2026-07-19
**Scope:** Proposed rewrite of `/privacy` and `/terms` marketing pages.
**Context change:** MicroFlow Pro is NOT a fintech SaaS for NBFCs/banks. It is a **digital ledger / record-keeping tool for individual local money-lenders and small lenders** who lend to acquaintances on trust, without Aadhaar/PAN/CIBIL verification and without formal registration. The app is a book-keeping tool, NOT a lending platform.

---

## CHANGES LIST (what was wrong + what changed)

### Privacy Policy
| # | Old (wrong framing) | New |
|---|---------------------|-----|
| P1 | Generic "we collect info you provide via contact form / demo" | Named data types actually stored: lender account + borrower records the lender enters (names, amounts, interest, repayments) |
| P2 | Implied web-only contacts | Explicit: borrower data is **stored securely on our servers, never sold, never shared** with third parties except processors needed to run the service |
| P3 | No identity-verification note | Added: **MicroFlow does NOT verify borrower identity** — lenders enter data on trust; accuracy is the lender's responsibility |
| P4 | No "who is this for" | Added clarifying line: tool is for **individuals who lend money locally** (neighbors, shopkeepers, informal lenders) |
| P5 | No legal disclaimer | Added: lender is solely responsible for local/state money-lending law compliance, interest-rate caps, and any registration requirement; MicroFlow gives no legal/financial advice |
| P6 | Kept data-security + rights | Kept, with minor wording |
| P7 | No draft marker | Marked **DRAFT — lawyer review** |
| P8 | Removed | No NBFC / eKYC / RBI digital-lending references (none were present, but framing confirmed clean) |

### Terms of Service
| # | Old (wrong framing) | New |
|---|---------------------|-----|
| T1 | "multi-tenant SaaS platform for microfinance institutions, field collections, branch management, org oversight" | "digital ledger / book-keeping tool for individual and small money-lenders to record loans, interest, and repayments" |
| T2 | Implied institutional customer | Added "Who is this for" — individuals who lend money locally |
| T3 | No identity / trust note | Added: MicroFlow does not verify borrowers; lender works on trust and owns data accuracy |
| T4 | Generic "comply with applicable laws" | Explicit: sole responsibility for money-lending law, interest caps, registration in their area; MicroFlow gives no legal/financial advice |
| T5 | Added subscription/OIDAR + GST 18% note | Added SaaS subscription section (software access only, not financial service); GST 18% on Indian subscriptions |
| T6 | Added refund policy | Added refund policy (prorated / no refund on used period, at our discretion) |
| T7 | Removed | No NBFC / RBI / eKYC framing |
| T8 | No draft marker | Marked **DRAFT — lawyer review** |

> Contact placeholders used: `legal@microflowpro.com` and `/contact` page link. Adjust before publishing.

---

## PROPOSED FILE 1: `marketing_site/app/(marketing)/privacy/page.tsx`

```tsx
import type { Metadata } from 'next';
import { buildMetadata } from '@/components/seo/buildMetadata';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';

export const metadata: Metadata = buildMetadata({
  title: 'Privacy Policy',
  description:
    'MicroFlow Pro privacy policy — how we store and protect the loan and borrower records you keep in your digital ledger.',
  path: '/privacy',
});

export default function PrivacyPage() {
  return (
    <Section>
      <Container className="max-w-3xl">
        <h1 className="font-display text-display-1 font-bold text-text">Privacy Policy</h1>
        <div className="prose prose-slate mt-8 max-w-none dark:prose-invert">
          <p>
            <strong>DRAFT — for lawyer review.</strong> Last updated: July 2026.
          </p>

          <h2>Who this is for</h2>
          <p>
            MicroFlow Pro is a digital ledger and record-keeping tool for{' '}
            <strong>individuals who lend money locally</strong> — such as neighbors,
            shopkeepers, and small informal lenders — to track the loans they give, the
            interest that accrues, and the repayments they collect. It is a book-keeping
            tool, <strong>not a bank, not an NBFC, and not a lending platform</strong>.
          </p>

          <h2>Information We Collect</h2>
          <p>We collect two kinds of information:</p>
          <ul>
            <li>
              <strong>Account information:</strong> the details you give us to create and
              manage your MicroFlow account (such as your name, email address, and
              subscription details).
            </li>
            <li>
              <strong>Ledger data you enter:</strong> the loan, borrower, interest, and
              repayment records you type into the app. This may include the names and
              contact details of the people you lend to, loan amounts, interest rates,
              due dates, and payment history.
            </li>
          </ul>
          <p>
            <strong>We do not verify borrower identity.</strong> MicroFlow is built on
            trust between you and the people you lend to. We do not collect, require, or
            check Aadhaar, PAN, CIBIL, or any government ID for borrowers. The accuracy of
            the records you enter is your responsibility.
          </p>

          <h2>How We Use Your Information</h2>
          <p>We use the information we collect to:</p>
          <ul>
            <li>Provide, operate, and secure the MicroFlow app and your account</li>
            <li>Process your subscription and send service-related notices</li>
            <li>Respond to your support requests</li>
            <li>Improve the app and fix problems</li>
          </ul>

          <h2>How We Share Your Information</h2>
          <p>
            We do <strong>not sell</strong> your data and we do <strong>not share</strong>{' '}
            your borrower records with third parties for marketing. The only sharing is
            with vetted service providers who help us run the product — such as cloud
            hosting, email delivery, and payment processing — and only to the extent
            needed to operate the service. We may also disclose data if required by law.
          </p>

          <h2>Data Security</h2>
          <p>
            We implement appropriate technical and organizational measures to protect your
            information and your ledger data against unauthorized access, alteration,
            disclosure, or destruction. Your borrower records are stored securely on our
            servers and are accessible only through your authenticated account.
          </p>

          <h2>Your Rights</h2>
          <p>
            You can access, correct, export, or delete your account and the ledger data
            you have entered at any time from within the app. To delete your account and
            all associated records, or to exercise any other data right, contact us at the
            email address below. On account deletion we remove your data according to our
            retention schedule.
          </p>

          <h2>Your Responsibility as a Lender</h2>
          <p>
            MicroFlow is a record-keeping tool only. You are solely responsible for
            complying with the money-lending laws, interest-rate limits, and any
            lender-registration requirements that apply in your state, district, or local
            area. MicroFlow does not provide legal, tax, or financial advice. If you are
            unsure whether you need to register as a money-lender or what interest you may
            lawfully charge, consult a qualified local professional.
          </p>

          <h2>Contact Us</h2>
          <p>
            If you have any questions about this Privacy Policy, please contact us at{' '}
            <a href="mailto:legal@microflowpro.com">legal@microflowpro.com</a> or through
            our <a href="/contact">contact page</a>.
          </p>
        </div>
      </Container>
    </Section>
  );
}
```

---

## PROPOSED FILE 2: `marketing_site/app/(marketing)/terms/page.tsx`

```tsx
import type { Metadata } from 'next';
import { buildMetadata } from '@/components/seo/buildMetadata';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';

export const metadata: Metadata = buildMetadata({
  title: 'Terms of Service',
  description:
    'MicroFlow Pro terms of service — the rules for using our digital ledger tool for individual money-lenders.',
  path: '/terms',
});

export default function TermsPage() {
  return (
    <Section>
      <Container className="max-w-3xl">
        <h1 className="font-display text-display-1 font-bold text-text">Terms of Service</h1>
        <div className="prose prose-slate mt-8 max-w-none dark:prose-invert">
          <p>
            <strong>DRAFT — for lawyer review.</strong> Last updated: July 2026.
          </p>

          <h2>Acceptance of Terms</h2>
          <p>
            By accessing or using MicroFlow Pro, you agree to be bound by these Terms of
            Service. If you do not agree, do not use the service.
          </p>

          <h2>What MicroFlow Pro Is</h2>
          <p>
            MicroFlow Pro is a <strong>digital ledger and book-keeping tool</strong> for
            individual and small money-lenders. It helps you record the loans you give,
            track interest accrual, and log repayments. It is software that stores your
            records — it is <strong>not a bank, not an NBFC, not a lending platform, and
            not a financial service</strong>. MicroFlow never lends money, never collects
            on your behalf, and never guarantees repayment.
          </p>

          <h2>Who This Is For</h2>
          <p>
            This tool is built for <strong>individuals who lend money locally</strong> to
            people they know — neighbors, customers, friends, and acquaintances — and who
            want a simple digital record of those arrangements.
          </p>

          <h2>No Borrower Verification</h2>
          <p>
            MicroFlow does <strong>not verify the identity</strong> of any borrower. Lending
            happens on trust between you and the people you lend to. You enter borrower
            details yourself, and you are responsible for the accuracy and lawfulness of
            the data you record.
          </p>

          <h2>Your Responsibilities</h2>
          <p>You are responsible for:</p>
          <ul>
            <li>Maintaining the confidentiality of your account credentials</li>
            <li>All activity that occurs under your account</li>
            <li>
              Complying with the money-lending laws, interest-rate caps, and any
              lender-registration requirements in your state, district, or local area
            </li>
            <li>The legality of every loan you record and the accuracy of the records you enter</li>
          </ul>

          <h2>No Legal or Financial Advice</h2>
          <p>
            MicroFlow provides a record-keeping tool only. We do not provide legal, tax,
            accounting, or financial advice, and nothing in the app should be taken as
            such. Whether you must register as a money-lender, what interest you may
            lawfully charge, and how you should document loans are matters for you to
            confirm with a qualified local professional.
          </p>

          <h2>Subscription</h2>
          <p>
            MicroFlow Pro is offered as a paid software subscription (SaaS). Your
            subscription grants you access to the app and the storage of your ledger data
            for the paid period. It does not constitute a financial service. For
            subscriptions billed to customers in India, the applicable Goods and Services
            Tax (GST) of 18% is charged as an OIDAR (online information and database
            access or retrieval) service, in line with Indian tax rules. Pricing and
            billing terms are shown on our pricing page at the time of purchase.
          </p>

          <h2>Refund Policy</h2>
          <p>
            Subscription fees are generally non-refundable once a billing period has
            started. Where required by law or at our discretion, we may offer a refund or
            prorated credit for the unused portion of a subscription. To request a refund,
            contact us using the details below. Free trials, if offered, are governed by
            their own terms at sign-up.
          </p>

          <h2>Limitation of Liability</h2>
          <p>
            To the maximum extent permitted by law, MicroFlow Pro shall not be liable for
            any indirect, incidental, special, consequential, or punitive damages arising
            from your use of the service, including any dispute between you and a borrower.
            The app is provided "as is" without warranty as to fitness for any particular
            purpose beyond general record-keeping.
          </p>

          <h2>Changes to Terms</h2>
          <p>
            We may update these terms from time to time. We will notify you of material
            changes by posting the updated terms on this page and, where practical, by
            email or in-app notice.
          </p>

          <h2>Contact</h2>
          <p>
            If you have questions about these Terms, please contact us at{' '}
            <a href="mailto:legal@microflowpro.com">legal@microflowpro.com</a> or through
            our <a href="/contact">contact page</a>.
          </p>
        </div>
      </Container>
    </Section>
  );
}
```

---

## Notes for Sayan before publishing
- Replace `legal@microflowpro.com` with the real legal/support address.
- A lawyer should confirm the GST 18% / OIDAR wording and the refund policy language for your jurisdiction.
- site-config.ts (`tagline` / `description`) still says "MFI" — that's a separate marketing copy task, not part of this legal rewrite, but worth flagging since it contradicts the new framing.
