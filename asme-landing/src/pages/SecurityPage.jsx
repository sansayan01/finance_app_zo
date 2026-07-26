import LegalPage, { LegalSection } from "../components/LegalPage";

export default function SecurityPage() {
  return (
    <LegalPage title="Security" updated="July 2026">
      <LegalSection title="Data Encryption">
        • All data transmitted between your device and our servers uses TLS 1.3
        encryption.{"\n"}
        • Data at rest is encrypted using industry-standard encryption on our
        cloud infrastructure.{"\n"}
        • Offline data stored on your device is protected by the platform's
        native keychain/keystore.
      </LegalSection>

      <LegalSection title="Access Control">
        • Only you can access your data — enforced by Row-Level Security (RLS)
        policies at the database level.{"\n"}
        • No one on our team can access your individual records without your
        explicit consent.{"\n"}
        • Authentication uses secure session tokens with configurable timeout.
      </LegalSection>

      <LegalSection title="Regular Audits">
        We review our security practices and infrastructure regularly. Third-party
        audits are conducted annually to ensure our systems meet industry
        standards.
      </LegalSection>

      <LegalSection title="Backup & Recovery">
        • Your data is backed up automatically to your configured storage
        (Google Drive or our cloud).{"\n"}
        • You can restore your data at any time from within the app.{"\n"}
        • Backup data is encrypted with the same protection as primary data.
      </LegalSection>

      <LegalSection title="Report a Security Issue">
        If you discover a security vulnerability or have concerns about your
        data, please reach out:{"\n\n"}
        Email: security@microflow.pro{"\n"}
        We take all reports seriously and will respond within 24 hours.
      </LegalSection>
    </LegalPage>
  );
}
