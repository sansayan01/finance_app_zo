import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const cardVariants = cva('rounded-xl2 p-6', {
  variants: {
    variant: {
      solid: 'bg-surface border border-border',
      glass: 'glass shadow-glass dark:shadow-glass-dk',
    },
  },
  defaultVariants: {
    variant: 'solid',
  },
});

export interface CardProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof cardVariants> {}

const Card = React.forwardRef<HTMLDivElement, CardProps>(
  ({ className, variant, ...props }, ref) => (
    <div
      ref={ref}
      className={cn(cardVariants({ variant, className }))}
      {...props}
    />
  ),
);
Card.displayName = 'Card';

export { Card, cardVariants };
