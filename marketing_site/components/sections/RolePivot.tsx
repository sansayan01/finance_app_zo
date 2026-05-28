import Link from 'next/link';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';

const ROLES = [
  { id: 'executive-admin', label: 'Executive Admin', description: 'Organization-wide dashboards, loan approvals, and compliance reports across all branches.' },
  { id: 'branch-manager', label: 'Branch Manager', description: 'Branch-level oversight, staff performance tracking, and area assignment management.' },
  { id: 'staff', label: 'Staff / Agent', description: 'Offline-first collections, GPS check-ins, daily targets, and gamified streaks.' },
  { id: 'customer', label: 'Customer', description: 'Self-service portal for loan status, payment history, and savings balance.' },
];

export function RolePivot() {
  return (
    <Section>
      <Container>
        <h2 className="font-display text-display-2 font-bold text-text">
          One platform, four perspectives
        </h2>
        <p className="mt-4 max-w-2xl text-text-muted">
          Each role gets exactly the tools they need. Select a role to learn more.
        </p>

        <div className="mt-12">
          {/* CSS-only tabs via radio inputs */}
          <div className="flex flex-wrap gap-2" role="tablist">
            {ROLES.map((r, i) => (
              <label key={r.id} className="cursor-pointer">
                <input
                  type="radio"
                  name="role-tab"
                  value={r.id}
                  defaultChecked={i === 0}
                  className="peer sr-only"
                />
                <span className="inline-block rounded-lg border border-border px-4 py-2 text-sm font-medium text-text-muted transition-colors peer-checked:border-indigo peer-checked:bg-indigo peer-checked:text-white">
                  {r.label}
                </span>
              </label>
            ))}
          </div>

          <div className="mt-8 grid gap-6 md:grid-cols-2">
            {ROLES.map((r) => (
              <div
                key={r.id}
                id={`panel-${r.id}`}
                className="rounded-xl2 border border-border bg-surface p-6"
              >
                <h3 className="font-display text-xl font-bold text-text">{r.label}</h3>
                <p className="mt-3 text-sm text-text-muted">{r.description}</p>
                <Link
                  href={`/features#${r.id}`}
                  className="mt-4 inline-block text-sm font-medium text-indigo transition-colors hover:text-indigo-dark"
                >
                  Learn more &rarr;
                </Link>
              </div>
            ))}
          </div>
        </div>
      </Container>
    </Section>
  );
}
