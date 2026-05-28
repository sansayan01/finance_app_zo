'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import Link from 'next/link';
import { siteConfig } from '@/lib/site-config';

export function MobileMenu() {
  const [open, setOpen] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);

  const close = useCallback(() => {
    setOpen(false);
    triggerRef.current?.focus();
  }, []);

  // Trap focus inside the panel when open
  useEffect(() => {
    if (!open) return;

    const panel = panelRef.current;
    if (!panel) return;

    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        close();
        return;
      }

      if (e.key !== 'Tab') return;

      const focusable = panel!.querySelectorAll<HTMLElement>(
        'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])',
      );
      if (focusable.length === 0) return;

      const first = focusable[0];
      const last = focusable[focusable.length - 1];

      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }

    document.addEventListener('keydown', handleKeyDown);
    // Focus first link on open
    const firstLink = panel.querySelector<HTMLElement>('a[href]');
    firstLink?.focus();

    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [open, close]);

  return (
    <div className="md:hidden">
      <button
        ref={triggerRef}
        type="button"
        aria-expanded={open}
        aria-controls="mobile-menu"
        onClick={() => setOpen((v) => !v)}
        className="inline-flex h-9 w-9 items-center justify-center rounded-md text-text-muted transition-colors hover:bg-surface-2"
      >
        <span className="sr-only">{open ? 'Close menu' : 'Open menu'}</span>
        {open ? (
          <svg aria-hidden className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        ) : (
          <svg aria-hidden className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        )}
      </button>

      {open && (
        <div
          id="mobile-menu"
          ref={panelRef}
          role="dialog"
          aria-label="Mobile navigation"
          className="absolute inset-x-0 top-16 border-b border-border bg-bg/95 backdrop-blur-md"
        >
          <div className="mx-auto max-w-7xl px-4 py-4 sm:px-6">
            <ul className="flex flex-col gap-1">
              {siteConfig.nav.map((item) => (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    onClick={close}
                    className="block rounded-md px-3 py-2 text-sm text-text-muted transition-colors hover:bg-surface-2 hover:text-text"
                  >
                    {item.label}
                  </Link>
                </li>
              ))}
            </ul>
            <div className="mt-4 flex flex-col gap-2 border-t border-border pt-4">
              <Link
                href={process.env.NEXT_PUBLIC_APP_SIGN_IN_URL ?? '#'}
                onClick={close}
                className="text-sm font-medium text-text-muted transition-colors hover:text-text"
              >
                Sign in
              </Link>
              <Link
                href="/contact"
                data-cta="book-demo"
                onClick={close}
                className="inline-flex h-10 items-center justify-center rounded-lg bg-brand px-4 text-sm font-medium text-white shadow-brand transition-opacity hover:opacity-90"
              >
                Book a Demo
              </Link>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
