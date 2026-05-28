import Link from 'next/link';
import { siteConfig } from '@/lib/site-config';
import { Container } from '@/components/ui/container';
import { MobileMenu } from '@/components/layout/MobileMenu';

export function Nav() {
  return (
    <header className="sticky top-0 z-50 glass">
      <Container>
        <nav className="flex h-16 items-center justify-between" aria-label="Primary">
          {/* Wordmark */}
          <Link href="/" className="font-display text-lg font-bold text-text">
            {siteConfig.name}
          </Link>

          {/* Desktop links */}
          <ul className="hidden items-center gap-1 md:flex">
            {siteConfig.nav.map((item) => (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className="rounded-md px-3 py-2 text-sm text-text-muted transition-colors hover:bg-surface-2 hover:text-text"
                >
                  {item.label}
                </Link>
              </li>
            ))}
          </ul>

          {/* Right side actions */}
          <div className="hidden items-center gap-3 md:flex">
            <Link
              href={process.env.NEXT_PUBLIC_APP_SIGN_IN_URL ?? '#'}
              className="text-sm font-medium text-text-muted transition-colors hover:text-text"
            >
              Sign in
            </Link>
            <Link
              href="/contact"
              data-cta="book-demo"
              className="inline-flex h-9 items-center rounded-lg bg-brand px-4 text-sm font-medium text-white shadow-brand transition-opacity hover:opacity-90"
            >
              Book a Demo
            </Link>
          </div>

          {/* Mobile menu */}
          <MobileMenu />
        </nav>
      </Container>
    </header>
  );
}
