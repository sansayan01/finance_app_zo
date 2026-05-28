import Link from 'next/link';
import { PRICING_TIERS } from '@/lib/pricing';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

export function PricingCards() {
  return (
    <Section>
      <Container>
        <h2 className="text-center font-display text-display-2 font-bold text-text">
          Simple, transparent plans
        </h2>
        <p className="mx-auto mt-4 max-w-2xl text-center text-text-muted">
          Every plan includes offline collections, multi-tenant security, and
          dedicated onboarding support.
        </p>

        <div className="mt-12 grid gap-8 md:grid-cols-3">
          {PRICING_TIERS.map((tier) => (
            <Card
              key={tier.id}
              variant="glass"
              className={cn(
                'relative flex flex-col',
                tier.recommended && 'ring-2 ring-indigo',
              )}
            >
              {tier.recommended && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2">
                  <Badge variant="recommended">Recommended</Badge>
                </div>
              )}

              <h3 className="font-display text-xl font-bold text-text">
                {tier.name}
              </h3>
              <p className="mt-2 text-sm text-text-muted">{tier.tagline}</p>

              <ul className="mt-6 flex-1 space-y-2">
                {tier.features.map((f) => (
                  <li key={f} className="flex items-start gap-2 text-sm text-text">
                    <svg aria-hidden className="mt-0.5 h-4 w-4 shrink-0 text-indigo" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                    {f}
                  </li>
                ))}
              </ul>

              <Link
                href={tier.cta.href}
                className="mt-8 inline-flex h-10 w-full items-center justify-center rounded-lg bg-brand text-sm font-medium text-white shadow-brand transition-opacity hover:opacity-90"
              >
                {tier.cta.label}
              </Link>
            </Card>
          ))}
        </div>
      </Container>
    </Section>
  );
}
