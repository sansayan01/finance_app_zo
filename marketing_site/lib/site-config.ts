/** Central site configuration — single source of truth for navigation, footer, and branding. */

export interface NavItem {
  label: string;
  href: string;
}

export interface SocialLink {
  platform: string;
  href: string;
  label: string;
}

export interface FooterConfig {
  legal: NavItem[];
  social: SocialLink[];
}

export interface SiteConfig {
  name: string;
  tagline: string;
  description: string;
  nav: NavItem[];
  footer: FooterConfig;
}

export const siteConfig: SiteConfig = {
  name: 'MicroFlow Pro',
  tagline: 'Run your MFI field operations from one app, online or off.',
  description:
    'MicroFlow Pro is the multi-tenant SaaS platform for Micro-Finance Institutions — powering offline collections, branch oversight, regulatory reporting, and gamified field teams.',
  nav: [
    { label: 'Features', href: '/features' },
    { label: 'Pricing', href: '/pricing' },
    { label: 'About', href: '/about' },
    { label: 'Blog', href: '/blog' },
    { label: 'Contact', href: '/contact' },
  ],
  footer: {
    legal: [
      { label: 'Privacy Policy', href: '/privacy' },
      { label: 'Terms of Service', href: '/terms' },
    ],
    social: [
      { platform: 'twitter', href: 'https://twitter.com/microflowpro', label: 'Twitter' },
      { platform: 'linkedin', href: 'https://linkedin.com/company/microflowpro', label: 'LinkedIn' },
      { platform: 'github', href: 'https://github.com/microflowpro', label: 'GitHub' },
    ],
  },
} as const;
