import type { Metadata } from 'next';
import { buildMetadata } from '@/components/seo/buildMetadata';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';
import { Card } from '@/components/ui/card';
import { CtaBand } from '@/components/sections/CtaBand';

export const metadata: Metadata = buildMetadata({
  title: 'Features',
  description:
    'Explore MicroFlow Pro features for every role in your MFI — from executive admins to field agents.',
  path: '/features',
});

const ROLES = [
  {
    id: 'executive-admin',
    title: 'Executive Admin',
    description:
      'Organization-wide dashboards, loan approvals, savings management, staff oversight, and compliance reports across all branches.',
    features: [
      'Real-time portfolio dashboard',
      'Multi-branch analytics',
      'Loan approval workflows',
      'Staff and role management',
      'Audit trail and compliance exports',
    ],
  },
  {
    id: 'branch-manager',
    title: 'Branch Manager',
    description:
      'Branch-level oversight with staff performance tracking, area assignment management, and local approvals.',
    features: [
      'Branch performance dashboard',
      'Staff assignment and monitoring',
      'Local loan and savings approvals',
      'Collection rate tracking',
      'Area-based route management',
    ],
  },
  {
    id: 'staff',
    title: 'Staff / Collection Agent',
    description:
      'Offline-first mobile app for field collections, GPS check-ins, daily targets, and gamified performance.',
    features: [
      'Offline collection recording',
      'GPS-tagged check-ins',
      'Digital receipts',
      'Daily targets and streaks',
      'Achievement badges and leaderboards',
    ],
  },
  {
    id: 'customer',
    title: 'Customer',
    description:
      'Self-service portal for loan status, repayment schedules, payment history, and savings balance.',
    features: [
      'Active loan overview',
      'Repayment schedule',
      'Payment history',
      'Savings balance and maturity',
      'Digital receipts',
    ],
  },
];

export default function FeaturesPage() {
  return (
    <>
      <Section>
        <Container>
          <h1 className="font-display text-display-1 font-bold text-text">
            Features built for every role
          </h1>
          <p className="mt-6 max-w-2xl text-lg text-text-muted">
            MicroFlow Pro provides tailored experiences for each role in your
            microfinance institution, from the field to the boardroom.
          </p>
        </Container>
      </Section>

      {ROLES.map((role, i) => (
        <Section key={role.id} id={role.id} className={i % 2 === 1 ? 'bg-surface' : ''}>
          <Container>
            <h2 className="font-display text-display-2 font-bold text-text">
              {role.title}
            </h2>
            <p className="mt-4 max-w-2xl text-text-muted">{role.description}</p>
            <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {role.features.map((f) => (
                <Card key={f} variant="glass">
                  <svg aria-hidden className="mb-3 h-5 w-5 text-indigo" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                  </svg>
                  <p className="text-sm font-medium text-text">{f}</p>
                </Card>
              ))}
            </div>
          </Container>
        </Section>
      ))}

      {/* Platform features */}
      <Section>
        <Container>
          <h2 className="font-display text-display-2 font-bold text-text">
            Platform capabilities
          </h2>
          <div className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {[
              { title: 'Offline Sync', desc: 'Record collections without internet. Data syncs automatically when connected.' },
              { title: 'Multi-Tenant RLS', desc: 'Row Level Security ensures every organization only sees its own data.' },
              { title: 'Audit Logging', desc: 'Every action is logged with timestamp, user, and IP for compliance.' },
              { title: 'Gamification', desc: 'Streaks, achievements, and leaderboards keep field teams motivated.' },
              { title: 'Role-Based Access', desc: 'Five granular roles from super admin to customer with scoped permissions.' },
              { title: 'GPS Verification', desc: 'Verify agent location at check-in and collection points.' },
            ].map((f) => (
              <Card key={f.title} variant="glass">
                <h3 className="text-lg font-semibold text-text">{f.title}</h3>
                <p className="mt-2 text-sm text-text-muted">{f.desc}</p>
              </Card>
            ))}
          </div>
        </Container>
      </Section>

      <CtaBand />
    </>
  );
}
