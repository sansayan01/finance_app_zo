# Requirements Document

## Introduction

The Marketing Landing Site is a standalone, public-facing Next.js (App Router, TypeScript, Tailwind CSS) marketing website for **MicroFlow Pro**, the multi-tenant Flutter SaaS platform for Micro-Finance Institutions (MFIs) and savings groups. The site lives at `marketing_site/` in the repository, separate from the Flutter app and the existing `web_portal/`.

The site targets **Executive Admin / MFI organization owners** as the primary audience, communicating operational value (manual collections, offline field staff, paper records, branch oversight, regulatory reporting, gamification of field teams) and routing qualified leads into a sales pipeline. It reuses the visual brand language established in the existing `landing_page.html` prototype.

The site is a multi-page experience with a landing page, features page, pricing page, about page, contact page, and an MDX-powered blog. It surfaces three calls to action: **Book a Demo** (third-party calendar embed) as the primary hero CTA, **Contact Sales** (Supabase-backed lead capture form) as the secondary CTA, and a **Sign in / Sign up** entry point in the navigation that links to the existing application. The site deploys to Vercel and meets WCAG 2.1 AA, modern SEO, and Core Web Vitals targets appropriate for a marketing site.

## Glossary

- **Marketing_Site**: The standalone Next.js application defined by this spec, hosted at `marketing_site/` and deployed to Vercel.
- **Landing_Page**: The home route (`/`) of the Marketing_Site.
- **Features_Page**: The route `/features` describing product capabilities.
- **Pricing_Page**: The route `/pricing` presenting subscription tiers.
- **About_Page**: The route `/about` describing the company and mission.
- **Contact_Page**: The route `/contact` hosting the Contact Sales form.
- **Blog_Index**: The route `/blog` listing published blog posts.
- **Blog_Post_Page**: The route `/blog/[slug]` rendering a single MDX blog post.
- **Navigation_Bar**: The persistent top navigation component rendered on every page.
- **Footer**: The persistent footer component rendered on every page.
- **Demo_Booking_Widget**: The embedded third-party calendar (Cal.com or Calendly) used to book product demos.
- **Contact_Form**: The Supabase-backed lead capture form on the Contact_Page.
- **Lead_Record**: A row persisted in the Supabase `marketing_leads` table representing one Contact_Form submission.
- **Pricing_Tier**: One of the three published plans — Starter, Growth, Enterprise.
- **Brand_System**: The visual design language reused from `landing_page.html`, defined as the indigo (#6366f1) → violet (#8b5cf6) primary gradient with cyan (#0ea5e9) accent, Outfit (display) and Plus Jakarta Sans (body) typography, glassmorphic navigation, and radial hero glow.
- **Theme_Mode**: The active color theme, either `light` or `dark`.
- **Executive_Admin_Visitor**: The primary audience persona — an MFI organization owner or executive evaluating MicroFlow Pro.
- **App_Sign_In_URL**: The configured external URL of the existing MicroFlow Pro application sign-in page (provided via environment variable).
- **WCAG_AA**: Web Content Accessibility Guidelines 2.1 Level AA conformance criteria.
- **Core_Web_Vitals**: Google's user-centric performance metrics: Largest Contentful Paint (LCP), Interaction to Next Paint (INP), and Cumulative Layout Shift (CLS).
- **Vercel_Deployment**: The production hosting target for the Marketing_Site.

## Requirements

### Requirement 1: Page Structure and Routing

**User Story:** As an Executive_Admin_Visitor, I want predictable URLs for every section of the marketing site, so that I can navigate, share, and bookmark specific pages.

#### Acceptance Criteria

1. THE Marketing_Site SHALL expose the routes `/`, `/features`, `/pricing`, `/about`, `/contact`, `/blog`, and `/blog/[slug]` using the Next.js App Router.
2. WHEN a visitor requests `/`, THE Marketing_Site SHALL render the Landing_Page with hero, value propositions, feature highlights, social proof, and a closing CTA section.
3. WHEN a visitor requests `/features`, THE Marketing_Site SHALL render the Features_Page describing Executive Admin, Branch Manager, Staff/Collection Agent, Customer, offline-first sync, multi-tenant security, and gamification capabilities.
4. WHEN a visitor requests `/pricing`, THE Marketing_Site SHALL render the Pricing_Page with the Starter, Growth, and Enterprise tiers and a feature comparison.
5. WHEN a visitor requests `/about`, THE Marketing_Site SHALL render the About_Page with mission, audience focus on MFIs, and team or company narrative.
6. WHEN a visitor requests `/contact`, THE Marketing_Site SHALL render the Contact_Page with the Contact_Form and the Demo_Booking_Widget.
7. WHEN a visitor requests `/blog`, THE Marketing_Site SHALL render the Blog_Index listing all published blog posts in reverse chronological order by publish date.
8. WHEN a visitor requests `/blog/[slug]` for a published post, THE Marketing_Site SHALL render the corresponding Blog_Post_Page.
9. IF a visitor requests `/blog/[slug]` for a slug that does not match any published post, THEN THE Marketing_Site SHALL respond with HTTP 404 and render a branded not-found page that includes navigation back to the Landing_Page and Blog_Index.
10. IF a visitor requests any path that is not a defined route, THEN THE Marketing_Site SHALL respond with HTTP 404 and render the same branded not-found page.

### Requirement 2: Hero and Messaging

**User Story:** As an Executive_Admin_Visitor, I want the Landing_Page hero to communicate MicroFlow Pro's value within seconds, so that I can quickly decide whether to engage further.

#### Acceptance Criteria

1. THE Landing_Page SHALL display a hero section above the fold containing a headline, supporting subheadline, primary CTA, and secondary CTA.
2. THE Landing_Page hero headline SHALL communicate a benefit oriented toward MFI organization owners (e.g., field collections, offline operations, branch oversight, regulatory reporting).
3. THE Landing_Page hero SHALL render the primary CTA labeled "Book a Demo" that opens the Demo_Booking_Widget flow as defined in Requirement 5.
4. THE Landing_Page hero SHALL render the secondary CTA labeled "Contact Sales" that navigates to the Contact_Page with focus moved to the Contact_Form.
5. THE Landing_Page SHALL include a value-proposition section enumerating at least four operational pain points addressed by the product (manual collections, offline field staff, paper records, branch oversight, regulatory reporting, or gamification).
6. THE Landing_Page SHALL include a feature highlights section that previews capabilities and links to the Features_Page for full detail.
7. THE Landing_Page SHALL include a closing CTA section that repeats the "Book a Demo" primary CTA and the "Contact Sales" secondary CTA.

### Requirement 3: Feature Showcase

**User Story:** As an Executive_Admin_Visitor, I want a structured features page, so that I can evaluate product capabilities relevant to my organization's roles.

#### Acceptance Criteria

1. THE Features_Page SHALL group capabilities by user role, including sections for Executive Admin, Branch Manager, Staff / Collection Agent, and Customer.
2. THE Features_Page SHALL describe the offline-first sync engine, including offline collection queueing and automatic synchronization when connectivity is restored.
3. THE Features_Page SHALL describe multi-tenant Row-Level-Security data isolation between organizations.
4. THE Features_Page SHALL describe gamification capabilities for field staff, including streaks, achievements, and leaderboards.
5. THE Features_Page SHALL describe audit logging and analytics capabilities for organization administrators.
6. THE Features_Page SHALL include a closing CTA section that renders the "Book a Demo" and "Contact Sales" CTAs.

### Requirement 4: Pricing Tier Presentation

**User Story:** As an Executive_Admin_Visitor, I want to compare pricing tiers and request a quote, so that I can identify the right plan for my MFI's size before contacting sales.

#### Acceptance Criteria

1. THE Pricing_Page SHALL display three Pricing_Tiers labeled Starter, Growth, and Enterprise.
2. THE Pricing_Page SHALL omit explicit monetary prices for every Pricing_Tier.
3. THE Pricing_Page SHALL display a feature comparison that lists which capabilities are included in each Pricing_Tier.
4. THE Pricing_Page SHALL render one CTA per Pricing_Tier card.
5. WHEN a visitor activates a Pricing_Tier CTA, THE Marketing_Site SHALL navigate to the Contact_Page with a query parameter that identifies the selected tier name.
6. WHEN the Contact_Page loads with a tier query parameter that matches a defined Pricing_Tier, THE Contact_Form SHALL pre-populate a tier-of-interest field with that tier name.
7. IF the Contact_Page loads with a tier query parameter that does not match a defined Pricing_Tier, THEN THE Contact_Form SHALL leave the tier-of-interest field empty and SHALL NOT render an error.
8. THE Pricing_Page SHALL visually highlight one recommended Pricing_Tier to guide visitor selection.

### Requirement 5: Demo Booking Flow

**User Story:** As an Executive_Admin_Visitor, I want to book a product demo from the marketing site, so that I can schedule a conversation without leaving the site or sending an email.

#### Acceptance Criteria

1. THE Marketing_Site SHALL integrate a third-party calendar provider (Cal.com or Calendly) as the Demo_Booking_Widget.
2. THE Marketing_Site SHALL load the calendar provider URL from an environment variable rather than hardcoding it in source.
3. WHEN a visitor activates any "Book a Demo" CTA, THE Marketing_Site SHALL display the Demo_Booking_Widget within an in-page experience (modal, drawer, or dedicated route) without navigating to the third-party domain in the same tab.
4. WHILE the Demo_Booking_Widget is open, THE Marketing_Site SHALL provide a visible control to dismiss the widget and return to the originating page.
5. IF the Demo_Booking_Widget fails to load within 10 seconds, THEN THE Marketing_Site SHALL display a fallback message instructing the visitor to use the Contact_Form and SHALL render a link to the Contact_Page.
6. THE Demo_Booking_Widget SHALL be operable using keyboard navigation alone, including opening, focusing input controls, and dismissing.

### Requirement 6: Contact and Lead Capture Flow

**User Story:** As an Executive_Admin_Visitor, I want to submit my organization's details to sales, so that the MicroFlow Pro team can follow up with relevant information.

#### Acceptance Criteria

1. THE Contact_Form SHALL collect the following fields: organization name, contact name, email, role, country, MFI size or active member count, message, and tier of interest.
2. THE Contact_Form SHALL mark organization name, contact name, email, and message as required and SHALL allow role, country, MFI size, and tier of interest to be optional.
3. WHEN a visitor submits the Contact_Form with all required fields populated and the email field matching a standard email format, THE Marketing_Site SHALL persist a Lead_Record to the Supabase `marketing_leads` table.
4. WHEN the Lead_Record is successfully persisted, THE Marketing_Site SHALL display a success confirmation in place of or directly above the form and SHALL clear the form fields.
5. IF a visitor submits the Contact_Form with a missing required field or an invalid email format, THEN THE Contact_Form SHALL display per-field validation messages identifying the offending fields and SHALL NOT submit the data.
6. IF the Contact_Form submission to Supabase fails due to a network or server error, THEN THE Marketing_Site SHALL display an error message that preserves the visitor's entered values and offers a retry control.
7. THE Marketing_Site SHALL submit the Contact_Form via a Next.js Route Handler or Server Action that uses a server-side Supabase key, and SHALL NOT expose any service-role key to the browser.
8. THE `marketing_leads` table SHALL have Row Level Security enabled with an insert-only policy for the anon or service role used by the Marketing_Site, and SHALL deny public select access.
9. THE Contact_Form SHALL include a hidden honeypot field and SHALL reject submissions in which the honeypot field is filled.
10. WHEN a Lead_Record is persisted, THE Marketing_Site SHALL record the submission timestamp, the source page (e.g., `/pricing` vs `/contact`), and the selected tier of interest if present.

### Requirement 7: Blog Structure (MDX)

**User Story:** As an Executive_Admin_Visitor, I want to read blog posts about MFI operations and product updates, so that I can evaluate the company's expertise and product trajectory.

#### Acceptance Criteria

1. THE Blog_Index SHALL list every published blog post sourced from MDX files, sorted in reverse chronological order by publish date.
2. THE Blog_Index SHALL display, for each post entry, the title, publish date, author name, estimated read time, and an excerpt.
3. THE Blog_Post_Page SHALL render MDX content with support for headings, paragraphs, lists, code blocks with syntax highlighting, images, and internal links.
4. THE Blog_Post_Page SHALL display the post title, publish date, author name, and estimated read time at the top of the post.
5. WHERE a blog post defines `draft: true` in its frontmatter, THE Marketing_Site SHALL exclude that post from the Blog_Index and SHALL respond with HTTP 404 when the corresponding `/blog/[slug]` is requested in production.
6. THE Marketing_Site SHALL generate static routes for every published blog post at build time using `generateStaticParams`.
7. THE Blog_Post_Page SHALL render a "Back to Blog" link that navigates to the Blog_Index.

### Requirement 8: Navigation and Footer

**User Story:** As an Executive_Admin_Visitor, I want a consistent header and footer across the site, so that I can move between pages and find supporting links predictably.

#### Acceptance Criteria

1. THE Navigation_Bar SHALL render on every page of the Marketing_Site and SHALL include links to `/features`, `/pricing`, `/about`, `/blog`, and `/contact`.
2. THE Navigation_Bar SHALL include a "Sign in" or "Sign in / Sign up" link that navigates the visitor to the App_Sign_In_URL configured via environment variable.
3. THE Navigation_Bar SHALL include a "Book a Demo" CTA that triggers the Demo_Booking_Widget flow.
4. WHILE the viewport width is below 768 pixels, THE Navigation_Bar SHALL collapse navigation links into a toggle-driven mobile menu.
5. WHEN the mobile menu is open, THE Navigation_Bar SHALL trap keyboard focus within the menu until the menu is dismissed.
6. THE Navigation_Bar SHALL apply a glassmorphic visual style consistent with the Brand_System and SHALL remain pinned to the top of the viewport during scroll.
7. THE Footer SHALL render on every page and SHALL include the product name, a tagline, primary navigation links, legal links (Privacy Policy, Terms of Service), and a copyright notice with the current year.
8. THE Footer SHALL include a Theme_Mode toggle control that switches between `light` and `dark` modes.

### Requirement 9: Brand System and Theming

**User Story:** As an Executive_Admin_Visitor, I want a polished, consistent visual experience in both light and dark modes, so that the site feels modern and trustworthy.

#### Acceptance Criteria

1. THE Marketing_Site SHALL implement the Brand_System using the indigo (#6366f1) to violet (#8b5cf6) primary gradient and cyan (#0ea5e9) accent color.
2. THE Marketing_Site SHALL load Outfit as the display typeface and Plus Jakarta Sans as the body typeface using `next/font` with appropriate font display settings.
3. THE Landing_Page hero SHALL render a radial gradient glow background consistent with the prototype in `landing_page.html`.
4. THE Marketing_Site SHALL support both `light` and `dark` Theme_Modes and SHALL persist the visitor's selected Theme_Mode across page navigations and across sessions on the same device.
5. WHEN the Theme_Mode changes, THE Marketing_Site SHALL update colors, surfaces, and gradients without a full page reload and without a flash of unstyled or incorrectly themed content on subsequent navigations.
6. WHEN a visitor first loads the Marketing_Site without a previously persisted Theme_Mode, THE Marketing_Site SHALL apply the Theme_Mode that matches the operating system's `prefers-color-scheme` setting.
7. THE Marketing_Site SHALL apply Brand_System tokens (colors, gradients, typography, spacing, radii) through Tailwind theme configuration so that styles are consistent across components.

### Requirement 10: Responsiveness and Accessibility

**User Story:** As an Executive_Admin_Visitor, I want the marketing site to be usable on any device and accessible to assistive technology, so that any team member can review it.

#### Acceptance Criteria

1. THE Marketing_Site SHALL render a usable layout without horizontal scrolling at viewport widths from 320 pixels to 1920 pixels.
2. THE Marketing_Site SHALL define responsive breakpoints for mobile (below 768 pixels), tablet (768 to 1023 pixels), and desktop (1024 pixels and above), and SHALL adapt navigation, grids, and typography at each breakpoint.
3. THE Marketing_Site SHALL meet WCAG_AA contrast ratios of at least 4.5:1 for normal body text and 3:1 for large text and UI components in both `light` and `dark` Theme_Modes.
4. THE Marketing_Site SHALL render every interactive element with a visible focus indicator that meets WCAG_AA non-text contrast requirements.
5. THE Marketing_Site SHALL provide descriptive `alt` text for every informational image and SHALL mark decorative images as such.
6. THE Marketing_Site SHALL define a single `<h1>` per page and SHALL use a logical heading hierarchy without skipping levels.
7. THE Contact_Form SHALL associate every input with a visible `<label>` and SHALL communicate validation errors using `aria-invalid` and `aria-describedby` linked to the relevant error message.
8. THE Marketing_Site SHALL be fully operable using keyboard navigation alone for all interactive elements, including the Navigation_Bar, mobile menu, Demo_Booking_Widget, Contact_Form, and Theme_Mode toggle.
9. THE Marketing_Site SHALL include a "Skip to main content" link that becomes visible on keyboard focus and that moves focus to the page's main content landmark.
10. THE Marketing_Site SHALL declare `lang="en"` on the root `<html>` element.

### Requirement 11: SEO and Social Sharing

**User Story:** As a marketing stakeholder, I want the site to rank well and share attractively, so that organic and referral traffic converts into qualified leads.

#### Acceptance Criteria

1. THE Marketing_Site SHALL define a unique `<title>` and `<meta name="description">` for every route using the Next.js Metadata API.
2. THE Marketing_Site SHALL expose `sitemap.xml` at the root of the deployed domain and SHALL list every public route, including all published Blog_Post_Pages.
3. THE Marketing_Site SHALL expose `robots.txt` at the root of the deployed domain and SHALL allow indexing of public routes by default.
4. THE Marketing_Site SHALL define Open Graph metadata (`og:title`, `og:description`, `og:image`, `og:url`, `og:type`) for every route.
5. THE Marketing_Site SHALL define Twitter Card metadata (`twitter:card`, `twitter:title`, `twitter:description`, `twitter:image`) for every route.
6. THE Marketing_Site SHALL generate a default Open Graph image and SHALL allow Blog_Post_Pages to override it via frontmatter.
7. THE Marketing_Site SHALL define a canonical URL for every route.
8. THE Blog_Post_Page SHALL include JSON-LD structured data of type `Article` with title, author, datePublished, and dateModified fields.
9. THE Marketing_Site SHALL define an absolute base URL through an environment variable and SHALL use that base URL when constructing canonical URLs, sitemap entries, and social share URLs.

### Requirement 12: Performance Budgets

**User Story:** As an Executive_Admin_Visitor, I want pages to load fast on typical connections, so that I do not abandon the site while evaluating it.

#### Acceptance Criteria

1. THE Landing_Page SHALL achieve a Largest Contentful Paint of 2.5 seconds or less at the 75th percentile on a simulated mobile 4G connection in Lighthouse.
2. THE Landing_Page SHALL achieve a Cumulative Layout Shift of 0.1 or less at the 75th percentile in Lighthouse.
3. THE Landing_Page SHALL achieve an Interaction to Next Paint of 200 milliseconds or less at the 75th percentile in Lighthouse.
4. THE Marketing_Site SHALL serve all images through the Next.js `<Image>` component or an equivalent that emits responsive `srcset` and modern formats (AVIF or WebP).
5. THE Marketing_Site SHALL render the Landing_Page, Features_Page, Pricing_Page, About_Page, Blog_Index, and Blog_Post_Pages using static generation or incremental static regeneration rather than per-request server rendering.
6. THE Marketing_Site SHALL load the Demo_Booking_Widget script lazily and SHALL NOT block the Landing_Page initial render on the third-party calendar provider.
7. THE Landing_Page initial JavaScript payload transferred to the browser SHALL be 200 kilobytes or less compressed, excluding lazy-loaded chunks.
8. THE Marketing_Site SHALL achieve a Lighthouse Performance score of 90 or higher and a Lighthouse Accessibility score of 95 or higher for the Landing_Page on a desktop run.

### Requirement 13: Vercel Deployment and Environment Configuration

**User Story:** As a developer, I want the marketing site to deploy reliably to Vercel with environment-driven configuration, so that production, preview, and local environments stay separated and secrets are not committed to source control.

#### Acceptance Criteria

1. THE Marketing_Site SHALL be deployable to Vercel from the `marketing_site/` directory of the repository as a standalone Next.js project.
2. THE Marketing_Site SHALL declare every external dependency through `package.json` and SHALL build successfully on Vercel using `next build` without additional manual steps beyond installing dependencies and setting environment variables.
3. THE Marketing_Site SHALL read all required runtime configuration from environment variables, including the Supabase URL, the Supabase publishable or service-role key used for lead inserts, the Demo_Booking_Widget URL, the App_Sign_In_URL, and the canonical site base URL.
4. THE Marketing_Site SHALL include a committed `.env.example` file that documents every required environment variable name without containing real secret values.
5. THE Marketing_Site SHALL exclude `.env`, `.env.local`, and any provider-specific secret files from version control through `.gitignore`.
6. WHEN a required environment variable is missing at build time or first request, THE Marketing_Site SHALL fail fast with a clear server-side error message that names the missing variable and SHALL NOT render the affected page with placeholder values.
7. THE Marketing_Site SHALL distinguish between server-only environment variables and `NEXT_PUBLIC_` browser-exposed variables, and SHALL NOT prefix any Supabase service-role key with `NEXT_PUBLIC_`.
8. WHEN a Vercel preview deployment is created for a pull request, THE Marketing_Site SHALL apply the preview environment variables defined in Vercel and SHALL include `X-Robots-Tag: noindex` headers on preview hostnames so preview deployments are not indexed by search engines.
