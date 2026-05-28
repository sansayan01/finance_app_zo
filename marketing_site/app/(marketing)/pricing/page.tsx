import type { Metadata } from 'next';
import { buildMetadata } from '@/components/seo/buildMetadata';
import { PricingCards } from '@/components/sections/PricingCards';
import { FeatureComparisonTable } from '@/components/sections/FeatureComparisonTable';
import { FaqAccordion } from '@/components/sections/FaqAccordion';
import { CtaBand } from '@/components/sections/CtaBand';

export const metadata: Metadata = buildMetadata({
  title: 'Pricing',
  description:
    'Simple, transparent pricing for MFIs of every size. Every plan includes offline collections and multi-tenant security.',
  path: '/pricing',
});

export default function PricingPage() {
  return (
    <>
      <PricingCards />
      <FeatureComparisonTable />
      <FaqAccordion />
      <CtaBand />
    </>
  );
}
