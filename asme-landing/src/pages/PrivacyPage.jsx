import LegalPage, { LegalSection } from "../components/LegalPage";

export default function PrivacyPage() {
  return (
    <LegalPage title="Privacy Policy" updated="July 2026">
      <LegalSection title="What This App Is">
        MicroFlow Pro is a private digital record-keeping (book-keeping) tool for
        individual money-lenders. It helps you keep track of who you have lent
        money to, the interest accrued, and the repayments you have collected.{"\n\n"}
        MicroFlow Pro is NOT a lending platform, an NBFC, or a bank. It does not
        lend money, hold funds, or process payments. It is simply a digital ledger
        that stores the records you choose to enter.
      </LegalSection>

      <LegalSection title="Information We Collect">
        • Your account details: Name, email, phone number, and login credentials{"\n"}
        • Records you enter: Borrower name, phone number, loan amount, interest
        terms, and repayment history — all typed in by you{"\n"}
        • Device metadata: App version, device type, and last activity timestamps{"\n"}
        • Support tickets: Subject, description, and communication history{"\n\n"}
        Borrower information is supplied entirely by you, the lender. We do not
        independently collect, buy, or gather any data about your borrowers. All
        data is stored securely in encrypted databases hosted on Supabase cloud
        infrastructure.
      </LegalSection>

      <LegalSection title="We Do Not Verify Borrower Identity">
        By design, MicroFlow Pro does NOT verify the identity of your borrowers.
        We do not perform Aadhaar, PAN, CIBIL, or any other identity or credit
        check.{"\n\n"}
        Money-lending between individuals is based on your own trust and judgement.
        The app records the details you enter as-is. Confirming who your borrower
        is, and whether to lend, is entirely your decision and responsibility.
      </LegalSection>

      <LegalSection title="How We Use Your Information">
        • Storing and displaying the records you enter{"\n"}
        • Calculating interest and repayment summaries from your data{"\n"}
        • Sending optional reminders (via SMS) that YOU choose to trigger{"\n"}
        • Backing up your ledger to your configured storage{"\n"}
        • Improving app performance and reliability{"\n"}
        • Providing customer support through the in-app ticketing system{"\n\n"}
        We do not use your data, or your borrowers' data, for advertising or
        profiling.
      </LegalSection>

      <LegalSection title="Data Sharing & Third Parties">
        • Cloud infrastructure (Supabase, Google Drive) — for secure data storage
        and backups{"\n"}
        • SMS provider — only when you choose to send a reminder to a borrower{"\n"}
        • Analytics services — aggregate, anonymised usage statistics only (no
        personal information){"\n\n"}
        We do NOT sell, rent, or trade your data or your borrowers' data to anyone
        for marketing purposes. We are not a payment processor and do not share
        data with payment gateways.
      </LegalSection>

      <LegalSection title="Data Security">
        • All data transmitted over TLS 1.3 encrypted connections{"\n"}
        • Row-Level Security (RLS) policies ensure only you can access your data{"\n"}
        • Sensitive credentials (API keys, passwords) are encrypted at rest{"\n"}
        • Offline data stored on-device is encrypted using platform keychain{"\n"}
        • Automatic session timeout and biometric authentication support{"\n"}
        • Configurable password complexity and two-factor authentication
      </LegalSection>

      <LegalSection title="Data Retention">
        • Active account data: Retained for as long as your account is active{"\n"}
        • Support tickets: Retained for 2 years after resolution{"\n"}
        • Backups: Retained according to the backup schedule you configure{"\n"}
        • Account deletion: On request, all your data is permanently purged within
        30 days{"\n\n"}
        You are in control of your records — you can edit or delete individual
        entries at any time.
      </LegalSection>

      <LegalSection title="Your Control Over Your Data">
        • Access: View all data associated with your account at any time{"\n"}
        • Correct: Edit any record that is inaccurate{"\n"}
        • Delete: Remove individual records or request full account deletion{"\n"}
        • Export: Download your data in standard formats (JSON, CSV){"\n\n"}
        To request a full data export or account deletion, submit a support ticket
        through the app.
      </LegalSection>

      <p className="text-white/30 text-xs pt-6 border-t border-white/[0.04]">
        This policy is a draft for review with a lawyer before publishing.
      </p>
    </LegalPage>
  );
}
