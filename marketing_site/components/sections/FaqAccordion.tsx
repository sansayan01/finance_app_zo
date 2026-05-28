import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';

const FAQS = [
  {
    q: 'How does offline collection work?',
    a: 'Field agents record payments on their device even without internet. Data is queued locally and automatically synced when connectivity returns, with conflict resolution built in.',
  },
  {
    q: 'Is my data secure?',
    a: 'Yes. Every table is protected by Row Level Security in Supabase. Each organization can only access its own data, and every action is logged in the audit trail.',
  },
  {
    q: 'Can I try before committing?',
    a: 'Absolutely. Book a demo to see the full platform in action, or contact sales to discuss a pilot program for your organization.',
  },
  {
    q: 'What devices are supported?',
    a: 'MicroFlow Pro runs on Android and iOS phones and tablets, plus a web dashboard for managers and administrators.',
  },
  {
    q: 'How long does onboarding take?',
    a: 'Most organizations are live within two weeks. We provide dedicated onboarding support, data migration assistance, and staff training.',
  },
  {
    q: 'Can I upgrade or downgrade my plan?',
    a: 'Yes. You can change your plan at any time. Changes take effect at the start of your next billing cycle.',
  },
];

export function FaqAccordion() {
  return (
    <Section>
      <Container className="max-w-3xl">
        <h2 className="text-center font-display text-display-2 font-bold text-text">
          Frequently asked questions
        </h2>

        <div className="mt-12 divide-y divide-border">
          {FAQS.map((faq) => (
            <details key={faq.q} className="group">
              <summary className="flex cursor-pointer items-center justify-between py-4 text-base font-medium text-text transition-colors hover:text-indigo">
                {faq.q}
                <svg aria-hidden className="ml-4 h-5 w-5 shrink-0 text-text-muted transition-transform group-open:rotate-180" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
                </svg>
              </summary>
              <p className="pb-4 text-sm leading-relaxed text-text-muted">{faq.a}</p>
            </details>
          ))}
        </div>
      </Container>
    </Section>
  );
}
