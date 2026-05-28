import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';

const STATS = [
  { value: 'Offline-first', label: 'Works without connectivity' },
  { value: '5 Roles', label: 'Granular role-based access' },
  { value: 'Multi-tenant', label: 'RLS-secured data isolation' },
  { value: 'Full audit', label: 'Every action logged' },
  { value: 'Gamified', label: 'Streaks & leaderboards' },
];

export function NumbersStrip() {
  return (
    <Section className="bg-surface">
      <Container>
        <div className="grid gap-8 text-center sm:grid-cols-2 lg:grid-cols-5">
          {STATS.map((s) => (
            <div key={s.value}>
              <p className="font-display text-2xl font-bold text-indigo">{s.value}</p>
              <p className="mt-1 text-sm text-text-muted">{s.label}</p>
            </div>
          ))}
        </div>
      </Container>
    </Section>
  );
}
