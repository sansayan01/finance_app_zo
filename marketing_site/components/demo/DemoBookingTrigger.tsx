'use client';

import { useState, lazy, Suspense } from 'react';
import { cn } from '@/lib/utils';

const DemoModal = lazy(() => import('@/components/demo/DemoModal'));

interface DemoBookingTriggerProps {
  variant?: 'primary' | 'ghost';
  className?: string;
  children?: React.ReactNode;
}

export function DemoBookingTrigger({
  variant = 'primary',
  className,
  children = 'Book a Demo',
}: DemoBookingTriggerProps) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        data-cta="book-demo"
        onClick={() => setOpen(true)}
        className={cn(
          variant === 'primary'
            ? 'inline-flex h-10 items-center rounded-lg bg-brand px-4 text-sm font-medium text-white shadow-brand transition-opacity hover:opacity-90'
            : 'inline-flex h-10 items-center rounded-lg px-4 text-sm font-medium text-text-muted transition-colors hover:bg-surface-2 hover:text-text',
          className,
        )}
      >
        {children}
      </button>

      {open && (
        <Suspense fallback={null}>
          <DemoModal onClose={() => setOpen(false)} />
        </Suspense>
      )}
    </>
  );
}
