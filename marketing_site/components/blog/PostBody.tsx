import type { ReactNode } from 'react';

interface PostBodyProps {
  children: ReactNode;
}

export function PostBody({ children }: PostBodyProps) {
  return (
    <div className="prose prose-slate max-w-none dark:prose-invert">
      {children}
    </div>
  );
}
