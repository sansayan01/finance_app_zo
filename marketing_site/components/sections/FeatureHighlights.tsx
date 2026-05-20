import Link from 'next/link';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';
import { Card } from '@/components/ui/card';

const FEATURES = [
  { title: 'Executive Admin', anchor: 'executive-admin', description: 'Organization-wide dashboards, approvals, and analytics.' },
  { title: 'Branch Manager', anchor: 'branch-manager', description: 'Branch-level oversight, staff performance, and area assignments.' },
  { title: 'Staff / Agent', anchor: 'staff', description: 'Offline collections, GPS check-ins, gamified targets.' },
  { title: 'Customer', anchor: 'customer', description: 'Self-service loan status, payment history, savings balance.' },
];

export function FeatureHighlights() {
  return (
    <Section className="bg-surface">
      <Container>
        <h2 className="font-display text-display-2 font-bold text-text">
          Built for every role in your MFI
        </h2>
        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {FEATURES.map((f) => (
            <Link key={f.anchor} href={`/features#${f.anchor}`} className="group">
              <Card className="transition-shadow hover:shadow-glass dark:hover:shadow-glass-dk">
                <h3 className="text-lg font-semibold text-text group-hover:text-indigo">
                  {f.title}
                </h3>
                <p className="mt-2 text-sm text-text-muted">{f.description}</p>
              </Card>
            </Link>
          ))}
        </div>
      </Container>
    </Section>
  );
}
