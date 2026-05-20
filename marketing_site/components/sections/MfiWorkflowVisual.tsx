import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';

export function MfiWorkflowVisual() {
  return (
    <Section>
      <Container>
        <h2 className="text-center font-display text-display-2 font-bold text-text">
          From field to headquarters
        </h2>
        <p className="mx-auto mt-4 max-w-2xl text-center text-text-muted">
          Data flows seamlessly from collection agents through branches to
          organization-level dashboards and reports.
        </p>

        <div className="mx-auto mt-12 max-w-4xl">
          <svg viewBox="0 0 800 200" fill="none" className="w-full" aria-label="Workflow diagram showing data flow from Field to Branch to Organization to Reports">
            {/* Nodes */}
            <rect x="20" y="60" width="160" height="80" rx="12" className="fill-surface stroke-border" strokeWidth="2" />
            <text x="100" y="95" textAnchor="middle" className="fill-text font-display text-sm font-bold">Field Agent</text>
            <text x="100" y="115" textAnchor="middle" className="fill-text-muted text-xs">Collections & GPS</text>

            {/* Arrow */}
            <path d="M180 100 H260" className="stroke-indigo" strokeWidth="2" markerEnd="url(#arrow)" />

            <rect x="260" y="60" width="160" height="80" rx="12" className="fill-surface stroke-border" strokeWidth="2" />
            <text x="340" y="95" textAnchor="middle" className="fill-text font-display text-sm font-bold">Branch</text>
            <text x="340" y="115" textAnchor="middle" className="fill-text-muted text-xs">Approvals & Staff</text>

            <path d="M420 100 H500" className="stroke-violet" strokeWidth="2" markerEnd="url(#arrow)" />

            <rect x="500" y="60" width="160" height="80" rx="12" className="fill-surface stroke-border" strokeWidth="2" />
            <text x="580" y="95" textAnchor="middle" className="fill-text font-display text-sm font-bold">Organization</text>
            <text x="580" y="115" textAnchor="middle" className="fill-text-muted text-xs">Dashboard & Users</text>

            <path d="M660 100 H740" className="stroke-cyan" strokeWidth="2" markerEnd="url(#arrow)" />

            {/* Reports node */}
            <rect x="700" y="60" width="80" height="80" rx="12" className="fill-surface stroke-border" strokeWidth="2" />
            <text x="740" y="100" textAnchor="middle" className="fill-text font-display text-sm font-bold">Reports</text>

            <defs>
              <marker id="arrow" markerWidth="8" markerHeight="8" refX="8" refY="4" orient="auto">
                <path d="M0 0 L8 4 L0 8" fill="none" className="stroke-text-muted" strokeWidth="1.5" />
              </marker>
            </defs>
          </svg>
        </div>
      </Container>
    </Section>
  );
}
