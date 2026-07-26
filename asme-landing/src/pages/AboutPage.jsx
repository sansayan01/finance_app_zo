import LegalPage, { LegalSection } from "../components/LegalPage";

export default function AboutPage() {
  return (
    <LegalPage title="About MicroFlow Pro" updated="July 2026">
      <LegalSection title="Who We Are">
        We're a small team building a digital book-keeping tool for individual
        money-lenders in India.{"\n\n"}
        Founded in 2024, MicroFlow Pro started from a simple observation: most
        small lenders still manage their books on paper notebooks or scattered
        spreadsheets. That works — until it doesn't. Missed repayments, confused
        interest calculations, and lost records are everyday problems.
      </LegalSection>

      <LegalSection title="Our Mission">
        Help small lenders replace notebooks with a clean, offline-first app
        that works even in areas with patchy internet.{"\n\n"}
        We believe technology should serve the people who use it — not the other
        way around. MicroFlow Pro is designed to be simple, fast, and
        respectful of how you already work. No unnecessary features, no forced
        cloud dependency, no corporate bloat.
      </LegalSection>

      <LegalSection title="What We're Not">
        MicroFlow Pro is a record-keeping tool — not a lending platform, not an
        NBFC, and not a bank. We don't lend money, hold funds, or process
        payments. We simply help you keep track of the lending you already do.
      </LegalSection>
    </LegalPage>
  );
}
