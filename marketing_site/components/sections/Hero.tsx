import Link from 'next/link';
import { Container } from '@/components/ui/container';

export function Hero() {
  return (
    <section className="relative isolate overflow-hidden">
      {/* Glow layer */}
      <div className="pointer-events-none absolute inset-0 -z-10 bg-hero-glow" />

      <Container className="grid min-h-[70vh] items-center gap-12 py-20 lg:grid-cols-2 lg:gap-16">
        {/* Copy */}
        <div>
          <h1 className="font-display text-display-1 font-bold text-text">
            Run your MFI field operations from one app, online or off
          </h1>
          <p className="mt-6 max-w-xl text-lg leading-relaxed text-text-muted">
            MicroFlow Pro gives microfinance institutions a single platform for
            offline collections, branch oversight, regulatory reporting, and
            gamified field teams.
          </p>
          <div className="mt-10 flex flex-wrap gap-4">
            <Link
              href="/contact"
              data-cta="book-demo"
              className="inline-flex h-12 items-center rounded-lg bg-brand px-6 text-base font-medium text-white shadow-brand transition-opacity hover:opacity-90"
            >
              Book a Demo
            </Link>
            <Link
              href="/contact#form"
              className="inline-flex h-12 items-center rounded-lg border border-border px-6 text-base font-medium text-text transition-colors hover:bg-surface-2"
            >
              Contact Sales
            </Link>
          </div>
        </div>

        {/* Product mock */}
        <div className="relative hidden lg:block">
          <div className="aspect-[4/3] rounded-2xl border border-border bg-surface shadow-glass dark:shadow-glass-dk">
            <div className="flex h-full items-center justify-center text-text-muted">
              <svg aria-hidden className="h-24 w-24 opacity-30" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
              </svg>
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}
