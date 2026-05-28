# MicroFlow Pro — Marketing Site

A standalone Next.js 14+ (App Router, TypeScript, Tailwind CSS) marketing website for **MicroFlow Pro**, the multi-tenant Flutter SaaS platform for Micro-Finance Institutions and savings groups.

The site lives at `marketing_site/` in the monorepo, separate from the Flutter app and the `web_portal/`. It targets MFI organization owners (Executive Admins) and routes qualified leads into a sales pipeline via a Supabase-backed contact form and an embedded demo-booking calendar.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Node.js | 20+ |
| pnpm | 9+ |

---

## Local Setup

```bash
# 1. Navigate to the marketing site directory
cd marketing_site

# 2. Install dependencies
pnpm install

# 3. Create your local env file
cp .env.example .env.local
# Edit .env.local with your actual values (see Environment Variables below)

# 4. Start the dev server
pnpm dev
```

The site will be available at `http://localhost:3000`.

---

## Environment Variables

All configuration is read from environment variables. See `.env.example` for the full template.

| Variable | Required | Exposed to Browser | Description |
|----------|----------|-------------------|-------------|
| `NEXT_PUBLIC_SITE_URL` | Yes | Yes | Canonical base URL of the deployed site (no trailing slash). Used for SEO, sitemap, and OG metadata. |
| `NEXT_PUBLIC_APP_SIGN_IN_URL` | Yes | Yes | URL of the MicroFlow Pro application sign-in page (linked from the nav). |
| `NEXT_PUBLIC_DEMO_BOOKING_URL` | Yes | Yes | Embeddable calendar URL for the "Book a Demo" widget (Cal.com or Calendly). |
| `NEXT_PUBLIC_PLAUSIBLE_DOMAIN` | No | Yes | Plausible Analytics domain. Omit to disable analytics. |
| `SUPABASE_URL` | Yes | No | Supabase project URL. |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | No | Supabase service-role key for server-side lead inserts. **Never** prefix with `NEXT_PUBLIC_`. |

> **Security note:** `SUPABASE_SERVICE_ROLE_KEY` is used exclusively in server actions and is never sent to the browser. The app will fail fast at build/runtime if any required variable is missing.

---

## Scripts Cheat Sheet

| Command | Description |
|---------|-------------|
| `pnpm dev` | Start the Next.js development server with hot reload |
| `pnpm build` | Production build (static generation + serverless functions) |
| `pnpm start` | Serve the production build locally |
| `pnpm lint` | Run ESLint (Next.js config) |
| `pnpm typecheck` | Run TypeScript type checking (`tsc --noEmit`) |
| `pnpm test` | Run unit and property-based tests (Vitest) |
| `pnpm test:e2e` | Run end-to-end tests (Playwright) |

---

## Project Layout

```
marketing_site/
├── app/
│   ├── (marketing)/          # Marketing pages with shared Nav + Footer layout
│   │   ├── page.tsx          # Landing page (/)
│   │   ├── features/         # /features
│   │   ├── pricing/          # /pricing
│   │   ├── about/            # /about
│   │   ├── contact/          # /contact
│   │   └── layout.tsx        # Shared marketing chrome
│   ├── blog/
│   │   ├── page.tsx          # Blog index (/blog)
│   │   └── [slug]/page.tsx   # Individual blog posts
│   ├── actions/
│   │   └── submit-lead.ts    # Server Action for contact form
│   ├── layout.tsx            # Root layout (fonts, ThemeProvider, html lang)
│   ├── not-found.tsx         # Branded 404 page
│   ├── sitemap.ts            # Dynamic sitemap generation
│   ├── robots.ts             # robots.txt generation
│   ├── opengraph-image.tsx   # Default OG image via @vercel/og
│   └── globals.css           # Tailwind layers + CSS custom properties
├── components/
│   ├── ui/                   # Shared primitives (Button, Input, Card, etc.)
│   ├── sections/             # Page section components (Hero, PricingCards, etc.)
│   ├── forms/                # ContactForm (client component)
│   ├── layout/               # Nav, Footer, ThemeToggle, MobileMenu, SkipLink
│   ├── demo/                 # DemoBookingTrigger, DemoModal
│   ├── blog/                 # PostCard, PostHeader, PostBody, ArticleJsonLd
│   └── seo/                  # buildMetadata helper
├── content/
│   └── blog/                 # MDX blog posts
├── lib/
│   ├── env.ts                # Zod-validated environment variables
│   ├── supabase/             # Server-side Supabase client + types
│   ├── site-config.ts        # Site name, nav links, footer config
│   ├── pricing.ts            # Pricing tier source of truth
│   ├── mdx.ts                # Blog post loading and parsing
│   └── utils.ts              # cn() and small helpers
├── public/                   # Static assets (favicon, OG fallback, SVGs)
├── middleware.ts             # Preview deployment noindex headers
├── next.config.mjs           # MDX plugin, image domains, typed routes
├── tailwind.config.ts        # Brand tokens, custom theme extensions
├── postcss.config.mjs        # PostCSS (Tailwind + autoprefixer)
├── tsconfig.json             # TypeScript strict config with path aliases
├── package.json              # Dependencies and scripts
├── pnpm-lock.yaml            # Lockfile
├── .env.example              # Environment variable template (committed)
├── .gitignore                # Ignores .env, node_modules, .next, etc.
├── vercel.json               # Optional Vercel headers config
└── README.md                 # This file
```

---

## Deployment (Vercel)

The site is designed to deploy to Vercel as a standalone Next.js project.

### Vercel Project Settings

| Setting | Value |
|---------|-------|
| **Root Directory** | `marketing_site` |
| **Framework Preset** | Next.js |
| **Install Command** | `pnpm install --frozen-lockfile` |
| **Build Command** | `next build` |
| **Output Directory** | `.next` (default) |

### Environment Variables on Vercel

Add all variables from `.env.example` in the Vercel dashboard under **Settings → Environment Variables**:

- **Production**: Set real values for `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `NEXT_PUBLIC_SITE_URL` (your production domain), `NEXT_PUBLIC_APP_SIGN_IN_URL`, and `NEXT_PUBLIC_DEMO_BOOKING_URL`.
- **Preview**: Use a separate Supabase project or branch for preview deployments. Preview builds automatically add `X-Robots-Tag: noindex` headers via middleware to prevent search engine indexing.

### Notes

- The build requires all required environment variables to be set. Missing variables will cause the build to fail with a descriptive error naming the missing key.
- `SUPABASE_SERVICE_ROLE_KEY` must **not** be prefixed with `NEXT_PUBLIC_` — it is server-only and never reaches the browser.
- Preview deployments on Vercel automatically receive `X-Robots-Tag: noindex, nofollow` headers to prevent indexing.
- For branch protection, ensure Vercel preview checks pass before merging to `main`.
