import type { Metadata } from 'next';
import { buildMetadata } from '@/components/seo/buildMetadata';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';

export const metadata: Metadata = buildMetadata({
  title: 'Privacy Policy',
  description: 'MicroFlow Pro privacy policy — how we collect, use, and protect your data.',
  path: '/privacy',
});

export default function PrivacyPage() {
  return (
    <Section>
      <Container className="max-w-3xl">
        <h1 className="font-display text-display-1 font-bold text-text">Privacy Policy</h1>
        <div className="prose prose-slate mt-8 max-w-none dark:prose-invert">
          <p>Last updated: January 2026</p>

          <h2>Information We Collect</h2>
          <p>
            We collect information you provide directly, such as when you fill out our
            contact form, book a demo, or communicate with us. This may include your
            name, email address, organization name, and any other information you
            choose to provide.
          </p>

          <h2>How We Use Your Information</h2>
          <p>We use the information we collect to:</p>
          <ul>
            <li>Respond to your inquiries and provide customer support</li>
            <li>Schedule and conduct demos</li>
            <li>Send you product updates and marketing communications (with your consent)</li>
            <li>Improve our website and services</li>
          </ul>

          <h2>Data Security</h2>
          <p>
            We implement appropriate technical and organizational measures to protect
            your personal information against unauthorized access, alteration,
            disclosure, or destruction.
          </p>

          <h2>Your Rights</h2>
          <p>
            You have the right to access, correct, or delete your personal data.
            To exercise these rights, please contact us at the email address
            provided on our contact page.
          </p>

          <h2>Contact Us</h2>
          <p>
            If you have any questions about this Privacy Policy, please contact us
            through our contact page.
          </p>
        </div>
      </Container>
    </Section>
  );
}
