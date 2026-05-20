import type { Metadata } from 'next';
import { buildMetadata } from '@/components/seo/buildMetadata';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';

export const metadata: Metadata = buildMetadata({
  title: 'Terms of Service',
  description: 'MicroFlow Pro terms of service — the rules governing your use of our platform.',
  path: '/terms',
});

export default function TermsPage() {
  return (
    <Section>
      <Container className="max-w-3xl">
        <h1 className="font-display text-display-1 font-bold text-text">Terms of Service</h1>
        <div className="prose prose-slate mt-8 max-w-none dark:prose-invert">
          <p>Last updated: January 2026</p>

          <h2>Acceptance of Terms</h2>
          <p>
            By accessing or using MicroFlow Pro, you agree to be bound by these
            Terms of Service. If you do not agree, do not use the service.
          </p>

          <h2>Description of Service</h2>
          <p>
            MicroFlow Pro is a multi-tenant SaaS platform for microfinance
            institutions, providing tools for field collections, branch management,
            and organizational oversight.
          </p>

          <h2>User Responsibilities</h2>
          <p>You are responsible for:</p>
          <ul>
            <li>Maintaining the confidentiality of your account credentials</li>
            <li>All activity that occurs under your account</li>
            <li>Ensuring your use complies with applicable laws and regulations</li>
          </ul>

          <h2>Limitation of Liability</h2>
          <p>
            To the maximum extent permitted by law, MicroFlow Pro shall not be
            liable for any indirect, incidental, special, consequential, or
            punitive damages arising from your use of the service.
          </p>

          <h2>Changes to Terms</h2>
          <p>
            We may update these terms from time to time. We will notify you of
            material changes by posting the updated terms on this page.
          </p>

          <h2>Contact</h2>
          <p>
            If you have questions about these Terms, please contact us through
            our contact page.
          </p>
        </div>
      </Container>
    </Section>
  );
}
