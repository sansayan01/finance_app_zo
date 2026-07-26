import LegalPage, { LegalSection } from "../components/LegalPage";

export default function TermsPage() {
  return (
    <LegalPage title="Terms of Service" updated="July 2026">
      <LegalSection title="Acceptance of Terms">
        By accessing and using MicroFlow Pro, you agree to be bound by these Terms
        of Service. If you do not agree to these terms, you must not use the
        application.{"\n\n"}
        These terms apply to you as the individual user (lender) of MicroFlow Pro.
      </LegalSection>

      <LegalSection title="What MicroFlow Pro Is">
        MicroFlow Pro is a private digital record-keeping tool for individual
        money-lenders. The application lets you:{"\n\n"}
        • Record the loans you have given, including amount and interest terms{"\n"}
        • Track repayments you have collected{"\n"}
        • View interest accrued and outstanding balances{"\n"}
        • Keep an organised, searchable ledger of your borrowers{"\n"}
        • Optionally send repayment reminders and back up your records{"\n\n"}
        The service is provided "as is" and may be updated, modified, or
        discontinued at our discretion with reasonable notice.
      </LegalSection>

      <LegalSection title="Not a Lender, NBFC, or Bank">
        MicroFlow Pro is only a record-keeping tool. It is NOT:{"\n\n"}
        • A lender — we do not lend money to you or anyone{"\n"}
        • An NBFC, bank, or financial institution{"\n"}
        • A lending marketplace or intermediary{"\n"}
        • A payment processor — we do not move, hold, or handle any money{"\n"}
        • A provider of credit scoring or identity verification{"\n\n"}
        All lending decisions, funds, agreements, and dealings are strictly
        between you and your borrowers. MicroFlow Pro is not a party to any loan
        you record in the app.
      </LegalSection>

      <LegalSection title="Your Legal Responsibility & Compliance">
        You, the user, are SOLELY responsible for the legality of your lending
        activity. This includes, but is not limited to:{"\n\n"}
        • Complying with all applicable local, state, and national money-lending
        laws{"\n"}
        • Obtaining any money-lender licence or registration required in your
        jurisdiction{"\n"}
        • Observing any legal limits on interest rates and charges that apply to
        you{"\n"}
        • Ensuring your dealings with borrowers are lawful and fair{"\n\n"}
        MicroFlow Pro does NOT provide legal, financial, tax, or regulatory advice,
        and nothing in the app should be treated as such. Laws differ by state and
        change over time — consult a qualified professional about your obligations.
        Using this app does not make your lending lawful, and we make no
        representation that it does.
      </LegalSection>

      <LegalSection title="User Responsibilities">
        • Maintaining the confidentiality of your login credentials{"\n"}
        • Ensuring the records you enter are accurate and lawful{"\n"}
        • Obtaining any consent required to store your borrowers' information{"\n"}
        • Using the app in compliance with the law in your jurisdiction{"\n"}
        • Reporting security vulnerabilities or bugs through proper channels{"\n"}
        • Not attempting to circumvent security measures or access controls{"\n\n"}
        Violation of these responsibilities may result in account suspension or
        termination.
      </LegalSection>

      <LegalSection title="Limitation of Liability">
        • MicroFlow Pro shall not be liable for indirect, incidental, or
        consequential damages{"\n"}
        • We are not liable for any dispute, loss, or default arising from loans
        you record{"\n"}
        • Total liability shall not exceed the subscription fees paid in the
        preceding 12 months{"\n"}
        • We are not liable for data loss resulting from force majeure events{"\n"}
        • We are not responsible for third-party service interruptions (SMS
        providers, cloud storage){"\n\n"}
        You should maintain independent backups of your records as a safeguard.
      </LegalSection>

      <LegalSection title="Termination">
        • By you: Contact support to initiate account deletion. Your data will be
        purged within 30 days.{"\n"}
        • By MicroFlow Pro: For violation of these terms, with 30 days notice to
        remediate{"\n"}
        • Upon termination: Access to the application ceases immediately. Data
        export is available for 30 days post-termination.
      </LegalSection>

      <p className="text-white/30 text-xs pt-6 border-t border-white/[0.04]">
        These terms are a draft for review with a lawyer before publishing.
      </p>
    </LegalPage>
  );
}
