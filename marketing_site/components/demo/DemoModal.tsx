'use client';

import { useEffect, useState, useCallback } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import Link from 'next/link';

interface DemoModalProps {
  onClose: () => void;
}

type ModalState = 'loading' | 'ready' | 'fallback';

export default function DemoModal({ onClose }: DemoModalProps) {
  const [state, setState] = useState<ModalState>('loading');
  const demoUrl = process.env.NEXT_PUBLIC_DEMO_BOOKING_URL ?? '';

  const handleLoad = useCallback(() => setState('ready'), []);

  // Timeout to fallback if iframe never loads
  useEffect(() => {
    const timer = setTimeout(() => {
      setState((prev) => (prev === 'loading' ? 'fallback' : prev));
    }, 10_000);
    return () => clearTimeout(timer);
  }, []);

  return (
    <Dialog.Root open onOpenChange={(v) => !v && onClose()}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-50 bg-black/50 backdrop-blur-sm" />
        <Dialog.Content
          aria-label="Book a demo"
          className="fixed left-1/2 top-1/2 z-50 w-[90vw] max-w-2xl -translate-x-1/2 -translate-y-1/2 rounded-xl2 bg-bg shadow-xl"
        >
          <div className="flex items-center justify-between border-b border-border px-6 py-4">
            <Dialog.Title className="font-display text-lg font-bold text-text">
              Book a Demo
            </Dialog.Title>
            <Dialog.Close className="rounded-md p-1 text-text-muted transition-colors hover:bg-surface-2 hover:text-text">
              <svg aria-hidden className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </Dialog.Close>
          </div>

          <div className="relative min-h-[400px]">
            {state === 'loading' && (
              <div className="flex h-[400px] items-center justify-center">
                <div className="h-8 w-8 animate-spin rounded-full border-2 border-indigo border-t-transparent" />
              </div>
            )}

            {state === 'fallback' && (
              <div className="flex h-[400px] flex-col items-center justify-center gap-4 p-8 text-center">
                <p className="text-text-muted">
                  The booking widget could not be loaded. Please contact us
                  directly to schedule your demo.
                </p>
                <Link
                  href="/contact?source=demo-fallback"
                  onClick={onClose}
                  className="inline-flex h-10 items-center rounded-lg bg-brand px-4 text-sm font-medium text-white shadow-brand transition-opacity hover:opacity-90"
                >
                  Go to Contact Page
                </Link>
              </div>
            )}

            {demoUrl && (
              <iframe
                src={demoUrl}
                title="Book a demo"
                loading="lazy"
                referrerPolicy="strict-origin-when-cross-origin"
                allow="camera; microphone; clipboard-write"
                onLoad={handleLoad}
                className={`h-[400px] w-full rounded-b-xl2 ${state === 'ready' ? '' : 'hidden'}`}
              />
            )}
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
