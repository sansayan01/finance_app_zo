/** Pricing tier source of truth — consumed by PricingCards, FeatureComparisonTable, and ContactForm. */

export type PricingTierId = 'starter' | 'growth' | 'enterprise';

export interface PricingTier {
  readonly id: PricingTierId;
  readonly name: string;
  readonly tagline: string;
  readonly features: readonly string[];
  readonly cta: {
    readonly label: string;
    readonly href: string;
  };
  readonly recommended: boolean;
}

export const PRICING_TIERS = [
  {
    id: 'starter',
    name: 'Starter',
    tagline: 'For new MFIs piloting digital collections.',
    features: ['Up to 1 branch', 'Up to 5 staff', 'Offline collections', 'Basic analytics'],
    cta: { label: 'Talk to Sales', href: '/contact?tier=starter' },
    recommended: false,
  },
  {
    id: 'growth',
    name: 'Growth',
    tagline: 'For growing MFIs running multi-branch operations.',
    features: [
      'Up to 10 branches',
      'Up to 100 staff',
      'Gamification',
      'Advanced analytics',
      'Custom roles',
    ],
    cta: { label: 'Talk to Sales', href: '/contact?tier=growth' },
    recommended: true,
  },
  {
    id: 'enterprise',
    name: 'Enterprise',
    tagline: 'For established MFIs with regulatory and SLA requirements.',
    features: [
      'Unlimited branches',
      'Unlimited staff',
      'SSO / SCIM',
      'SLA & dedicated support',
      'Audit exports',
    ],
    cta: { label: 'Talk to Sales', href: '/contact?tier=enterprise' },
    recommended: false,
  },
] as const satisfies readonly PricingTier[];

/** Look up a pricing tier by its id. Returns `undefined` for unknown ids. */
export function getTierById(id: string): PricingTier | undefined {
  return PRICING_TIERS.find((tier) => tier.id === id);
}
