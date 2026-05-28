import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import { Outfit, Plus_Jakarta_Sans } from 'next/font/google';
import { ThemeProvider } from '@/components/layout/ThemeProvider';
import { SkipLink } from '@/components/layout/SkipLink';

const outfit = Outfit({
  subsets: ['latin'],
  variable: '--font-outfit',
  display: 'swap',
});

const jakarta = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-jakarta',
  display: 'swap',
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000'),
  title: {
    default: 'MicroFlow Pro — MFI Field Operations Platform',
    template: '%s | MicroFlow Pro',
  },
  description:
    'MicroFlow Pro is the multi-tenant SaaS platform for Micro-Finance Institutions — powering offline collections, branch oversight, regulatory reporting, and gamified field teams.',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${outfit.variable} ${jakarta.variable}`}
    >
      <body className="min-h-screen bg-bg font-sans text-text antialiased">
        <ThemeProvider>
          <SkipLink />
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
