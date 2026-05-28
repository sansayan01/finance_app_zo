import type { Metadata } from 'next';
import { buildMetadata } from '@/components/seo/buildMetadata';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';
import { Card } from '@/components/ui/card';
import { CtaBand } from '@/components/sections/CtaBand';

export const metadata: Metadata = buildMetadata({
  title: 'About',
  description:
    'MicroFlow Pro is built for microfinance institutions that need reliable, offline-first field operations software.',
  path: '/about',
});

const VALUES = [
  {
    title: 'Offline-first',
    description:
      'We believe connectivity should never be a barrier. Every feature works offline and syncs seamlessly.',
  },
  {
    title: 'Security by default',
    description:
      'Multi-tenant Row Level Security, encrypted data, and comprehensive audit logging are built in, not bolted on.',
  },
  {
    title: 'Designed for MFIs',
    description:
      'We focus exclusively on microfinance institutions, so every feature solves a real MFI problem.',
  },
  {
    title: 'Accessible to all',
    description:
      'WCAG AA compliant, keyboard navigable, and responsive from 320px to 4K screens.',
  },
];

export default function AboutPage() {
  return (
    <>
      <Section>
        <Container className="max-w-3xl">
          <h1 className="font-display text-display-1 font-bold text-text">
            Our mission
          </h1>
          <p className="mt-6 text-lg leading-relaxed text-text-muted">
            MicroFlow Pro exists to give microfinance institutions the technology
            they deserve — reliable, secure, and built for the realities of field
            operations in emerging markets.
          </p>
          <p className="mt-4 text-lg leading-relaxed text-text-muted">
            We started because we saw MFIs struggling with paper-based processes,
            disconnected systems, and software that failed when connectivity
            dropped. Every feature in MicroFlow Pro is designed to work offline
            first, sync reliably, and give every role in the organization exactly
            the tools they need.
          </p>
        </Container>
      </Section>

      <Section className="bg-surface">
        <Container>
          <h2 className="font-display text-display-2 font-bold text-text">
            Our values
          </h2>
          <div className="mt-12 grid gap-6 sm:grid-cols-2">
            {VALUES.map((v) => (
              <Card key={v.title} variant="glass">
                <h3 className="text-lg font-semibold text-text">{v.title}</h3>
                <p className="mt-2 text-sm text-text-muted">{v.description}</p>
              </Card>
            ))}
          </div>
        </Container>
      </Section>

      <Section>
        <Container className="max-w-3xl">
          <h2 className="font-display text-display-2 font-bold text-text">
            The MFI focus
          </h2>
          <p className="mt-4 text-text-muted">
            Unlike generic fintech platforms, MicroFlow Pro is purpose-built for
            microfinance. Our role hierarchy maps directly to how MFIs operate:
            super admins manage the platform, executive admins run organizations,
            branch managers oversee local operations, collection agents work in
            the field, and customers access their own data.
          </p>
          <p className="mt-4 text-text-muted">
            This focus means we can offer features that general-purpose tools
            cannot: offline-first collections with GPS verification,
            multi-tenant data isolation with Row Level Security, gamified
            performance tracking for field agents, and regulatory audit trails
            that satisfy compliance requirements.
          </p>
        </Container>
      </Section>

      <CtaBand />
    </>
  );
}
