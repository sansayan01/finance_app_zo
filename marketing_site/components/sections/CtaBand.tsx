import Link from 'next/link';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';

export function CtaBand() {
  return (
    <Section className="bg-brand text-white">
      <Container className="text-center">
        <h2 className="font-display text-display-2 font-bold">
          Ready to modernize your field operations?
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-white/80">
          Book a demo to see MicroFlow Pro in action, or reach out to our sales
          team for a custom walkthrough.
        </p>
        <div className="mt-10 flex flex-wrap justify-center gap-4">
          <Link
            href="/contact"
            data-cta="book-demo"
            className="inline-flex h-12 items-center rounded-lg bg-white px-6 text-base font-medium text-indigo shadow-lg transition-opacity hover:opacity-90"
          >
            Book a Demo
          </Link>
          <Link
            href="/contact#form"
            className="inline-flex h-12 items-center rounded-lg border border-white/30 px-6 text-base font-medium text-white transition-colors hover:bg-white/10"
          >
            Contact Sales
          </Link>
        </div>
      </Container>
    </Section>
  );
}
