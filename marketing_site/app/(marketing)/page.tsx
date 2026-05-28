import type { Metadata } from 'next';
import { buildMetadata } from '@/components/seo/buildMetadata';
import { Hero } from '@/components/sections/Hero';
import { PainPoints } from '@/components/sections/PainPoints';
import { FeatureHighlights } from '@/components/sections/FeatureHighlights';
import { RolePivot } from '@/components/sections/RolePivot';
import { NumbersStrip } from '@/components/sections/NumbersStrip';
import { MfiWorkflowVisual } from '@/components/sections/MfiWorkflowVisual';
import { CtaBand } from '@/components/sections/CtaBand';

export const metadata: Metadata = buildMetadata({
  title: 'MicroFlow Pro — MFI Field Operations Platform',
  description:
    'Run your MFI field operations from one app. Offline collections, branch oversight, regulatory reporting, and gamified field teams.',
  path: '/',
});

export default function HomePage() {
  return (
    <>
      <Hero />
      <PainPoints />
      <FeatureHighlights />
      <RolePivot />
      <NumbersStrip />
      <MfiWorkflowVisual />
      <CtaBand />
    </>
  );
}
