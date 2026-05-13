# MicroFlow Pro - SaaS Scale Plan

## Executive Summary

Transform MicroFlow Pro from a multi-tenant app into a world-class B2B SaaS platform with:
- Subscription billing with Stripe
- Self-service onboarding
- Advanced analytics
- API for integrations
- White-label capabilities
- Enterprise features

---

## Phase 1: Subscription & Billing System

### 1.1 Stripe Integration

**Database Tables:**
```sql
-- Subscriptions
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  stripe_customer_id TEXT UNIQUE,
  stripe_subscription_id TEXT UNIQUE,
  plan_id TEXT NOT NULL,
  status TEXT DEFAULT 'active',
  current_period_start TIMESTAMP WITH TIME ZONE,
  current_period_end TIMESTAMP WITH TIME ZONE,
  cancel_at_period_end BOOLEAN DEFAULT false,
  trial_end TIMESTAMP WITH TIME ZONE,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Plan definitions
CREATE TABLE subscription_plans (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  price_monthly DECIMAL(10,2) NOT NULL,
  price_yearly DECIMAL(10,2),
  max_members INTEGER DEFAULT 100,
  max_branches INTEGER DEFAULT 1,
  max_staff INTEGER DEFAULT 5,
  features JSONB DEFAULT '[]'::jsonb,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0
);

-- Invoices
CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  stripe_invoice_id TEXT UNIQUE,
  subscription_id UUID REFERENCES subscriptions(id),
  amount DECIMAL(12,2) NOT NULL,
  currency TEXT DEFAULT 'INR',
  status TEXT DEFAULT 'draft',
  invoice_url TEXT,
  invoice_pdf TEXT,
  due_date TIMESTAMP WITH TIME ZONE,
  paid_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Payment methods
CREATE TABLE payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  stripe_payment_method_id TEXT UNIQUE,
  type TEXT NOT NULL,
  last4 TEXT,
  brand TEXT,
  exp_month INTEGER,
  exp_year INTEGER,
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
```

**Plans to Seed:**
| Plan | Monthly | Yearly | Members | Branches | Staff |
|------|---------|--------|---------|----------|-------|
| Starter | ₹999 | ₹9,999 | 100 | 1 | 3 |
| Growth | ₹2,499 | ₹24,999 | 500 | 5 | 15 |
| Professional | ₹4,999 | ₹49,999 | 2,000 | 15 | 50 |
| Enterprise | Custom | Custom | Unlimited | Unlimited | Unlimited |

### 1.2 Stripe Webhook Handler (Supabase Edge Function)

```typescript
// supabase/functions/stripe-webhook/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@12.0.0"

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
})

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

serve(async (req) => {
  const signature = req.headers.get('stripe-signature')
  const body = await req.text()
  
  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, signature!, Deno.env.get('STRIPE_WEBHOOK_SECRET')!)
  } catch (e) {
    return new Response(`Webhook Error: ${e.message}`, { status: 400 })
  }

  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.Checkout.Session
      const orgId = session.metadata?.org_id
      
      await supabase.from('subscriptions').upsert({
        org_id: orgId,
        stripe_customer_id: session.customer,
        stripe_subscription_id: session.subscription,
        plan_id: session.metadata?.plan_id,
        status: 'active',
        current_period_start: new Date().toISOString(),
      })
      
      // Update org status
      await supabase.from('organizations').update({
        status: 'active',
        plan_id: session.metadata?.plan_id,
      }).eq('id', orgId)
      break
    }
    
    case 'invoice.paid': {
      const invoice = event.data.object as Stripe.Invoice
      await supabase.from('invoices').upsert({
        stripe_invoice_id: invoice.id,
        org_id: invoice.metadata?.org_id,
        amount: invoice.amount_paid / 100,
        status: 'paid',
        invoice_url: invoice.hosted_invoice_url,
        invoice_pdf: invoice.invoice_pdf,
        paid_at: new Date().toISOString(),
      })
      break
    }
    
    case 'invoice.payment_failed': {
      const invoice = event.data.object as Stripe.Invoice
      await supabase.from('subscriptions').update({
        status: 'past_due',
      }).eq('stripe_subscription_id', invoice.subscription)
      break
    }
    
    case 'customer.subscription.deleted': {
      const subscription = event.data.object as Stripe.Subscription
      await supabase.from('subscriptions').update({
        status: 'canceled',
      }).eq('stripe_subscription_id', subscription.id)
      
      // Suspend org
      const { data } = await supabase.from('subscriptions')
        .select('org_id')
        .eq('stripe_subscription_id', subscription.id)
        .single()
      
      if (data) {
        await supabase.from('organizations').update({
          status: 'suspended',
        }).eq('id', data.org_id)
      }
      break
    }
  }

  return new Response(JSON.stringify({ received: true }), { status: 200 })
})
```

### 1.3 Flutter Billing UI

**Pages needed:**
- `/billing` - Plan selection & current subscription
- `/billing/checkout` - Stripe checkout redirect
- `/billing/invoices` - Invoice history
- `/billing/payment-methods` - Manage cards

---

## Phase 2: Self-Service Onboarding

### 2.1 Enhanced Signup Flow

```
Landing Page → Signup → Email Verification → 
Create Org → Setup Wizard → Dashboard
```

### 2.2 Trial System

- 14-day free trial
- Full feature access during trial
- Auto-downgrade to limited plan after trial
- Email reminders at day 7, 12, 14

### 2.3 Invitation System

**Database:**
```sql
CREATE TABLE org_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL,
  branch_id UUID REFERENCES branches(id),
  invited_by UUID REFERENCES profiles(id),
  token TEXT UNIQUE NOT NULL,
  status TEXT DEFAULT 'pending',
  expires_at TIMESTAMP WITH TIME ZONE,
  accepted_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
```

---

## Phase 3: Analytics & Reporting

### 3.1 Organization Analytics

- Collection efficiency trends
- Staff performance metrics
- Member retention rates
- Revenue forecasting

### 3.2 Export System

- CSV export for all data
- Scheduled email reports
- Custom report builder

### 3.3 Dashboard Customization

- Drag-and-drop widgets
- Custom KPIs
- Saved views

---

## Phase 4: API & Integrations

### 4.1 Public API

**REST Endpoints:**
- `/api/v1/members` - CRUD
- `/api/v1/loans` - CRUD
- `/api/v1/collections` - Read + Create
- `/api/v1/transactions` - Read
- `/api/v1/webhooks` - Custom webhooks

### 4.2 API Keys Management

```sql
CREATE TABLE api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  key_hash TEXT NOT NULL,
  prefix TEXT NOT NULL, -- First 8 chars for display
  scopes TEXT[] DEFAULT ARRAY['read'],
  last_used_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
```

### 4.3 Zapier/Make Integration

- Triggers: New member, Collection recorded, Loan disbursed
- Actions: Create member, Record collection

---

## Phase 5: White-Labeling

### 5.1 Custom Domain

- CNAME setup for custom domains
- SSL auto-provisioning
- Domain verification

### 5.2 Branding Options

- Logo upload
- Color scheme
- Email templates with brand
- Custom login page

### 5.3 Reseller Program

- White-label for MFI consultants
- Revenue sharing model
- Separate branding per tenant

---

## Phase 6: Enterprise Features

### 6.1 SSO (SAML/OAuth)

- Okta integration
- Azure AD integration
- Google Workspace

### 6.2 Audit Logs

- All actions logged
- Retention policies
- Export for compliance

### 6.3 Data Residency

- Region selection for data storage
- GDPR compliance tools
- Data deletion on account closure

### 6.4 SLA & Support

- Priority support tiers
- Uptime guarantees
- Dedicated account managers

---

## Phase 7: Growth Features

### 7.1 Referral Program

- Invite other MFIs
- Earn subscription credits
- Track referral status

### 7.2 Marketplace

- Pre-built templates
- Integration plugins
- Community contributions

### 7.3 Mobile App Stores

- Play Store listing
- App Store listing
- Deep linking

---

## Phase 8: Operations

### 8.1 Monitoring

- Application performance monitoring
- Error tracking (Sentry)
- Uptime monitoring

### 8.2 Customer Success

- In-app chat
- Knowledge base
- Video tutorials

### 8.3 Status Page

- Public status page
- Incident management
- Maintenance windows

---

## Implementation Priority

| Priority | Phase | Timeline |
|----------|-------|----------|
| 🔴 P0 | Subscription Billing | Week 1-2 |
| 🔴 P0 | Trial System | Week 2 |
| 🟠 P1 | Invitation System | Week 3 |
| 🟠 P1 | API & Keys | Week 3-4 |
| 🟡 P2 | Export System | Week 5 |
| 🟡 P2 | White-Labeling | Week 5-6 |
| 🟢 P3 | Enterprise Features | Week 7-8 |
| 🟢 P3 | Growth Features | Week 9+ |

---

## Tech Stack Additions

| Purpose | Tool |
|---------|------|
| Billing | Stripe |
| Email | Resend + React Email |
| Monitoring | Sentry |
| Analytics | PostHog / Mixpanel |
| Status | Instatus |
| Support | Crisp / Intercom |
| API Docs | Scalar / Swagger |

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Trial → Paid Conversion | > 15% |
| Monthly Churn | < 5% |
| NPS Score | > 50 |
| Support Response Time | < 4 hours |
| Uptime | 99.9% |
| MRR Growth | 20% MoM |

---

*Last Updated: May 13, 2026*
