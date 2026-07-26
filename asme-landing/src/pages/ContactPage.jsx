import LegalPage, { LegalSection } from "../components/LegalPage";

export default function ContactPage() {
  return (
    <LegalPage title="Contact Us" updated="July 2026">
      <LegalSection title="Get in Touch">
        We're here to help. Whether you have a question about features, need
        support, or want to share feedback — reach out anytime.
      </LegalSection>

      <LegalSection title="Email Support">
        support@microflow.pro{"\n\n"}
        We respond to all emails within 24 hours during business days.
      </LegalSection>

      <LegalSection title="In-App Support">
        The fastest way to get help is through the app itself. Open the support
        section to submit a ticket — our team will get back to you directly.
      </LegalSection>

      <LegalSection title="Security Concerns">
        For security-related issues, contact:{"\n\n"}
        security@microflow.pro
      </LegalSection>
    </LegalPage>
  );
}
