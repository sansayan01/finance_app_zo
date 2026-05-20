import { Suspense } from 'react';
import type { Metadata } from 'next';
import { buildMetadata } from '@/components/seo/buildMetadata';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';
import { ContactForm } from '@/components/forms/ContactForm';

export const metadata: Metadata = buildMetadata({
  title: 'Contact',
  description:
    'Get in touch with the MicroFlow Pro team. Book a demo, ask a question, or request a custom walkthrough.',
  path: '/contact',
});

export default function ContactPage() {
  return (
    <Section>
      <Container>
        <div className="mx-auto max-w-2xl text-center">
          <h1 className="font-display text-display-1 font-bold text-text">
            Get in touch
          </h1>
          <p className="mt-4 text-lg text-text-muted">
            Book a demo, ask a question, or tell us about your MFI. We&apos;d
            love to hear from you.
          </p>
        </div>

        <div id="form" className="mx-auto mt-12 max-w-xl">
          <Suspense
            fallback={
              <div className="flex h-64 items-center justify-center">
                <div className="h-8 w-8 animate-spin rounded-full border-2 border-indigo border-t-transparent" />
              </div>
            }
          >
            <ContactForm />
          </Suspense>
        </div>
      </Container>
    </Section>
  );
}
