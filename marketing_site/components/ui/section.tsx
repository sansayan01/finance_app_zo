import * as React from 'react';
import { cn } from '@/lib/utils';

export interface SectionProps extends React.HTMLAttributes<HTMLElement> {}

const Section = React.forwardRef<HTMLElement, SectionProps>(
  ({ className, ...props }, ref) => (
    <section
      ref={ref}
      className={cn('py-16 sm:py-20 lg:py-24', className)}
      {...props}
    />
  ),
);
Section.displayName = 'Section';

export { Section };
