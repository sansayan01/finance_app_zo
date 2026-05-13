# MicroFlow Pro - SaaS Roadmap

## Phase 1: Multi-Tenancy ✅
- [x] Organizations table + org_id on all tables
- [x] RLS policies for org isolation
- [x] Staff portal tables (branches, staff_profiles, collections, etc.)
- [x] Dart code updated with orgId in models/repositories/providers

## Phase 2: Organization Signup & Auth ✅
- [x] Signup page with org name field
- [x] Creates organization + admin profile on signup
- [x] Role-based routing (superAdmin → /admin, staff → /staff, admin → /)
- [x] superAdmin role added

## Phase 3: Setup Wizard ✅
- [x] 4-step wizard: Branch → Staff → Member → Done
- [x] Visual progress bar
- [x] Skip any step

## Phase 4: Super Admin Panel ✅
- [x] Admin dashboard with org list
- [x] Org detail page with suspend/delete
- [x] Role-gated routes

## Phase 5: Landing Page ✅
- [x] `landing_page.html` - marketing site
- [x] Features, pricing tiers, CTA

## Phase 6: Billing Framework ✅
- [x] Subscription model with tiers
- [x] Plan limits (max_members, max_branches, max_staff)
- [x] Stripe/Razorpay integration point ready

## Phase 7: Email Notifications ✅
- [x] EmailService class (Resend integration)
- [x] Welcome email, overdue alerts

## Phase 8: White-Labeling ✅
- [x] BrandModel loads from org settings
- [x] Org name, logo, primary color as brand

## Phase 9: CI/CD ✅
- [x] GitHub Actions: analyze, test, build web, build android
- [x] Artifact upload for deployment

---

## What's Left (Nice-to-Have)
- [ ] Stripe webhook handling (server-side)
- [ ] Actual Stripe subscription checkout flow
- [ ] Push notifications via FCM
- [ ] Data export (CSV/Excel)
- [ ] Multi-language support
- [ ] Dark/light theme per org
- [ ] iOS TestFlight deployment
