import Link from 'next/link';
import { siteConfig } from '@/lib/site-config';
import { Container } from '@/components/ui/container';
import { ThemeToggle } from '@/components/layout/ThemeToggle';

export function Footer() {
  return (
    <footer className="border-t border-border bg-surface">
      <Container>
        <div className="grid gap-8 py-12 sm:grid-cols-2 lg:grid-cols-4">
          {/* Brand */}
          <div className="sm:col-span-2 lg:col-span-1">
            <p className="font-display text-lg font-bold text-text">
              {siteConfig.name}
            </p>
            <p className="mt-2 text-sm text-text-muted">{siteConfig.tagline}</p>
          </div>

          {/* Product links */}
          <div>
            <h3 className="text-sm font-semibold text-text">Product</h3>
            <ul className="mt-3 flex flex-col gap-2">
              {siteConfig.nav.map((item) => (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    className="text-sm text-text-muted transition-colors hover:text-text"
                  >
                    {item.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Legal links */}
          <div>
            <h3 className="text-sm font-semibold text-text">Legal</h3>
            <ul className="mt-3 flex flex-col gap-2">
              {siteConfig.footer.legal.map((item) => (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    className="text-sm text-text-muted transition-colors hover:text-text"
                  >
                    {item.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Theme toggle + social */}
          <div>
            <h3 className="text-sm font-semibold text-text">Preferences</h3>
            <div className="mt-3">
              <ThemeToggle />
            </div>
          </div>
        </div>

        <div className="flex items-center justify-between border-t border-border py-6 text-xs text-text-muted">
          <p>&copy; {new Date().getFullYear()} {siteConfig.name}. All rights reserved.</p>
          <div className="flex gap-4">
            {siteConfig.footer.social.map((s) => (
              <a
                key={s.platform}
                href={s.href}
                target="_blank"
                rel="noopener noreferrer"
                className="transition-colors hover:text-text"
                aria-label={s.label}
              >
                {s.label}
              </a>
            ))}
          </div>
        </div>
      </Container>
    </footer>
  );
}
