import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';

const FEATURES_MATRIX = [
  { feature: 'Branches', starter: '1', growth: 'Up to 10', enterprise: 'Unlimited' },
  { feature: 'Staff seats', starter: 'Up to 5', growth: 'Up to 100', enterprise: 'Unlimited' },
  { feature: 'Offline collections', starter: true, growth: true, enterprise: true },
  { feature: 'Gamification', starter: false, growth: true, enterprise: true },
  { feature: 'Advanced analytics', starter: false, growth: true, enterprise: true },
  { feature: 'Custom roles', starter: false, growth: true, enterprise: true },
  { feature: 'SSO / SCIM', starter: false, growth: false, enterprise: true },
  { feature: 'SLA & dedicated support', starter: false, growth: false, enterprise: true },
  { feature: 'Audit exports', starter: false, growth: false, enterprise: true },
];

function Cell({ value }: { value: boolean | string }) {
  if (typeof value === 'string') return <span>{value}</span>;
  return value ? (
    <svg aria-hidden className="mx-auto h-5 w-5 text-indigo" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
    </svg>
  ) : (
    <svg aria-hidden className="mx-auto h-5 w-5 text-text-muted/30" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
    </svg>
  );
}

export function FeatureComparisonTable() {
  return (
    <Section>
      <Container>
        <h2 className="text-center font-display text-display-2 font-bold text-text">
          Compare plans
        </h2>

        <div className="mt-12 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-border">
                <th scope="col" className="py-3 pr-4 font-semibold text-text">Feature</th>
                <th scope="col" className="px-4 py-3 text-center font-semibold text-text">Starter</th>
                <th scope="col" className="px-4 py-3 text-center font-semibold text-indigo">Growth</th>
                <th scope="col" className="px-4 py-3 text-center font-semibold text-text">Enterprise</th>
              </tr>
            </thead>
            <tbody>
              {FEATURES_MATRIX.map((row) => (
                <tr key={row.feature} className="border-b border-border/50">
                  <td className="py-3 pr-4 text-text">{row.feature}</td>
                  <td className="px-4 py-3 text-center text-text-muted"><Cell value={row.starter} /></td>
                  <td className="px-4 py-3 text-center text-text-muted"><Cell value={row.growth} /></td>
                  <td className="px-4 py-3 text-center text-text-muted"><Cell value={row.enterprise} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Container>
    </Section>
  );
}
