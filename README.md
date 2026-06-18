<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?style=for-the-badge&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Supabase-2.0+-3ECF8E?style=for-the-badge&logo=supabase" alt="Supabase">
  <img src="https://img.shields.io/badge/Dart-3.4+-0175C2?style=for-the-badge&logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/Version-1.0.1-blue?style=for-the-badge" alt="Version">
</div>

<h1 align="center">MicroFlow Pro</h1>
<p align="center"><strong>Premium Micro-Finance Management Ecosystem</strong></p>
<p align="center">Complete Admin Portal + Field Staff Collector App + Customer Portal</p>

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Role-Based Portals](#role-based-portals)
  - [Super Admin Portal](#super-admin-portal)
  - [Executive Admin Portal](#executive-admin-portal)
  - [Branch Manager Portal](#branch-manager-portal)
  - [Staff / Collection Agent Portal](#staff--collection-agent-portal)
  - [Customer Portal](#customer-portal)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Database Schema](#database-schema)
- [Edge Functions](#edge-functions)
- [Scheduled Jobs & Views](#scheduled-jobs--views)
- [SMS & Messaging](#sms--messaging)
- [Statement Generation](#statement-generation)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [Running the App](#running-the-app)
- [Offline Support](#offline-support)
- [Security](#security)
- [Testing](#testing)
- [Code Statistics](#code-statistics)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

MicroFlow Pro is a **cross-platform financial management application** built with Flutter and Supabase, designed for Micro-Finance Institutions (MFIs) and savings groups. It provides a complete ecosystem for managing loans, savings, collections, members, and field operations across five role-based portals.

### Key Capabilities

| Portal | Users | Scope |
|--------|-------|-------|
| **Super Admin** | Platform operators | Organization management, platform settings, billing |
| **Executive Admin** | Org administrators | Loan/savings management, staff oversight, analytics |
| **Branch Manager** | Branch leads | Branch-level operations, staff performance, approvals |
| **Staff / Collection Agent** | Field collectors | Collections, customer visits, GPS tracking, offline ops |
| **Customer** | End users | Loan status, payment history, savings, support |

---

## Architecture

The app follows a **feature-first clean architecture** with Riverpod for state management and GoRouter for navigation.

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│         Pages  ──▶  Widgets  ──▶  Providers             │
├─────────────────────────────────────────────────────────┤
│                      Data Layer                         │
│     Repositories  ──▶  Services  ──▶  Models            │
├─────────────────────────────────────────────────────────┤
│                    Backend (Supabase)                    │
│    PostgreSQL  ──▶  RLS Policies  ──▶  Edge Functions   │
├─────────────────────────────────────────────────────────┤
│                   Local Storage                          │
│         Hive (offline cache)  ──▶  SharedPreferences     │
└─────────────────────────────────────────────────────────┘
```

---

## Role-Based Portals

### Super Admin Portal

Full platform management for operators overseeing multiple organizations.

| Page | Purpose |
|------|---------|
| `super_admin_dashboard.dart` | Platform-wide overview and metrics |
| `organizations_management_page.dart` | Create, manage, suspend organizations |
| `users_management_page.dart` | Platform user management |
| `platform_analytics_page.dart` | Cross-org analytics and reporting |
| `platform_settings_page.dart` | Global platform configuration |
| `platform_health_page.dart` | System health monitoring |
| `platform_map_page.dart` | Geographic distribution view |
| `security_scorecard_page.dart` | Security posture assessment |
| `feature_flags_page.dart` | Feature toggle management |
| `feature_adoption_page.dart` | Feature usage analytics |
| `audit_logs_page.dart` | Platform-wide audit trail |
| `report_center_page.dart` | Centralized report generation |
| `support_tickets_page.dart` | Support ticket management |
| `notification_center_page.dart` | Platform notifications |
| `announcements_page.dart` | System-wide announcements |
| `background_jobs_page.dart` | Scheduled job monitoring |
| `onboarding_management_page.dart` | Org onboarding workflows |
| `maintenance_page.dart` | Maintenance mode controls |
| `nps_survey_page.dart` | Net Promoter Score surveys |
| `system_controls_page.dart` | System-level controls |
| `executive_summary_page.dart` | Executive dashboard |
| `revenue_reconciliation_page.dart` | Revenue tracking and reconciliation |

### Executive Admin Portal

Organization-level management for administrators overseeing branches and staff.

| Page | Purpose |
|------|---------|
| `home_page.dart` | Dashboard with real-time stats, trends, quick actions |
| `loans_page.dart` | Loan list with status tracking |
| `loan_detail_page.dart` | Individual loan details, EMI schedule |
| `new_loan_page.dart` | Loan creation workflow |
| `edit_loan_page.dart` | Loan modification |
| `savings_page.dart` | Savings plan management |
| `saving_detail_page.dart` | Individual savings details |
| `new_recurring_saving_page.dart` | Create recurring savings |
| `edit_savings_vault_page.dart` | Edit savings vault |
| `users_page.dart` | Staff and manager management |
| `new_user_page.dart` | Create new staff users |
| `user_details_page.dart` | Staff profile and performance |
| `user_audit_page.dart` | User activity audit |
| `org_chart_page.dart` | Organizational hierarchy |
| `bulk_import_members_page.dart` | Bulk member onboarding |
| `member_onboarding_page.dart` | Individual member onboarding |
| `analytics_page.dart` | Collection and performance analytics |
| `transactions_page.dart` | Transaction history |
| `search_page.dart` | Global search |
| `notifications_page.dart` | Notification center |
| `branch_management_page.dart` | Branch office management |
| `today_payments_page.dart` | Today's payment overview |
| `billing_page.dart` | Subscription and billing |
| `invoices_page.dart` | Invoice management |
| `usage_limits_page.dart` | Usage limit monitoring |
| `branding_settings_page.dart` | White-label branding |

### Branch Manager Portal

Branch-level operations with staff oversight and performance tracking.

| Page | Purpose |
|------|---------|
| `branch_manager_dashboard.dart` | Branch stats, staff performance |
| `branch_collections_page.dart` | Branch collection tracking |
| `branch_loans_page.dart` | Branch loan management |
| `branch_savings_page.dart` | Branch savings management |
| `branch_members_page.dart` | Branch member list |
| `branch_member_detail_page.dart` | Individual member details |
| `branch_users_page.dart` | Branch staff management |
| `branch_analytics_page.dart` | Branch performance analytics |
| `branch_reports_page.dart` | Branch report generation |
| `branch_today_payments_page.dart` | Today's branch payments |
| `branch_settings_page.dart` | Branch configuration |
| `manager_live_map_page.dart` | Real-time staff location map |

### Staff / Collection Agent Portal

Field operations for collection agents with offline support, GPS tracking, and gamification.

| Page | Purpose |
|------|---------|
| `staff_home_dashboard.dart` | Dashboard: wallet, streak, targets, agenda |
| `staff_today_payments_page.dart` | Today's EMI collection queue |
| `collection_form_page.dart` | Record payment with GPS, multiple modes |
| `staff_user_hub_page.dart` | Customer search and management |
| `staff_timeline_page.dart` | Activity timeline and history |
| `staff_map_page.dart` | Live map with customer locations |
| `staff_settings_page.dart` | Staff profile and preferences |
| `staff_targets_page.dart` | Daily/weekly/monthly targets |
| `visit_checkin_page.dart` | GPS-tagged visit check-in/out |
| `cash_deposit_page.dart` | Submit cash to branch |
| `break_logging_page.dart` | Work break tracking |
| `pending_operations_page.dart` | Offline operation queue |
| `gamification_dashboard.dart` | Streaks, achievements, leaderboards |

### Customer Portal

Self-service portal for loan recipients and savings members.

| Page | Purpose |
|------|---------|
| `customer_home_page.dart` | Dashboard: loans, savings, stats |
| `customer_loans_page.dart` | Active loans list |
| `customer_loan_detail_page.dart` | Loan details, repayment schedule |
| `customer_emi_schedule_page.dart` | EMI calendar view |
| `customer_savings_page.dart` | Savings plans overview |
| `customer_savings_detail_page.dart` | Individual savings details |
| `customer_transactions_page.dart` | Payment history |
| `customer_notifications_page.dart` | Notifications inbox |
| `customer_support_page.dart` | Support ticket creation |
| `customer_profile_page.dart` | Profile management |
| `customer_account_settings_page.dart` | Account settings |
| `customer_feedback_page.dart` | Feedback submission |
| `customer_emi_calculator_page.dart` | EMI calculator tool |
| `customer_receipt_page.dart` | Payment receipt view |

---

## Tech Stack

### Frontend

| Technology | Purpose |
|------------|---------|
| **Flutter 3.11+** | Cross-platform UI framework |
| **Dart 3.4+** | Language runtime |
| **Riverpod 2.6+** | State management |
| **GoRouter 14.6+** | Declarative routing |
| **Flutter Animate** | Smooth animations |
| **FL Chart** | Charts and visualizations |
| **Table Calendar** | Calendar widgets |
| **Google Fonts** | Typography |
| **Shimmer** | Loading placeholders |

### Backend

| Technology | Purpose |
|------------|---------|
| **Supabase** | PostgreSQL database, Auth, Realtime, Edge Functions |
| **Row Level Security** | Data isolation per role |
| **PostgreSQL Functions** | Server-side logic |

### Local Storage & Offline

| Technology | Purpose |
|------------|---------|
| **Hive** | Local database for offline data |
| **SharedPreferences** | Settings, tokens |
| **Connectivity Plus** | Network status monitoring |

### Integrations & Utilities

| Technology | Purpose |
|------------|---------|
| **Geolocator** | GPS location tracking |
| **Mapbox Maps** | Map rendering and visualization |
| **Flutter Map** | Map rendering |
| **Local Auth** | Biometric authentication (fingerprint/face) |
| **Speech-to-Text** | Voice input for chatbot |
| **Flutter TTS** | Text-to-speech output |
| **QR Flutter** | QR code generation |
| **PDF / Printing** | Statement and receipt generation |
| **CSV / Excel** | Export capabilities |
| **Share Plus** | Receipt sharing |
| **Sentry** | Error tracking and telemetry |
| **PostHog** | Product analytics |
| **Dio** | HTTP client |
| **Image Picker / Compress** | Image handling |
| **File Picker** | File selection |
| **Battery Plus** | Battery status |
| **Permission Handler** | Runtime permissions |
| **URL Launcher** | External link handling |
| **Path Provider** | File system paths |
| **Package Info Plus** | App version info |

### Dev Dependencies

| Technology | Purpose |
|------------|---------|
| **Mocktail** | Mocking for tests |
| **Build Runner** | Code generation |
| **Freezed** | Immutable data classes |
| **JSON Serializable** | JSON serialization |
| **Flutter Driver** | Integration testing |
| **Integration Test** | End-to-end testing |
| **Flutter Lints** | Static analysis |

---

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── app.dart                           # MaterialApp configuration
│
├── core/
│   ├── config/
│   │   └── env_config.dart            # Environment variables
│   ├── constants/
│   │   ├── app_colors.dart            # Color palette
│   │   ├── app_spacing.dart           # Spacing constants
│   │   ├── app_typography.dart        # Typography styles
│   │   ├── enums.dart                 # App-wide enumerations
│   │   ├── layout.dart                # Layout breakpoints
│   │   └── sms_templates.dart         # SMS message templates
│   ├── models/
│   │   ├── statement_org_info.dart    # Statement org details
│   │   └── system_config.dart         # System configuration model
│   ├── presentation/pages/
│   │   ├── sms_history_page.dart      # SMS history view
│   │   └── sms_settings_page.dart     # SMS settings
│   ├── providers/
│   │   ├── branding_provider.dart     # Branding state
│   │   ├── location_providers.dart    # GPS location state
│   │   ├── org_provider.dart          # Organization state
│   │   ├── sms_config_provider.dart   # SMS config state
│   │   ├── sms_outbox_provider.dart   # SMS outbox state
│   │   ├── sms_provider.dart          # SMS state
│   │   ├── storage_providers.dart     # SharedPreferences
│   │   └── system_config_provider.dart # System config state
│   ├── services/
│   │   ├── app_icon_service.dart      # Dynamic app icon
│   │   ├── app_update_service.dart    # In-app update checks
│   │   ├── avatar_upload_service.dart # Avatar management
│   │   ├── email_service.dart         # Email notifications
│   │   ├── haptic_service.dart        # Haptic feedback
│   │   ├── image_compress_service.dart # Image compression
│   │   ├── live_location_service.dart # Real-time GPS streaming
│   │   ├── location_service.dart      # GPS utilities
│   │   ├── offline_queue_service.dart # Offline operation queue
│   │   ├── sms_outbox_service.dart    # SMS delivery
│   │   ├── sms_scheduler_service.dart # Scheduled SMS
│   │   └── sms_service.dart           # SMS provider integration
│   ├── theme/
│   │   ├── app_theme.dart             # Light/Dark themes
│   │   ├── design_system.dart         # Design tokens
│   │   └── theme_provider.dart        # Theme switching
│   ├── utils/
│   │   ├── auto_refresh_mixin.dart    # Auto-refresh mixin
│   │   ├── calculations.dart          # Financial calculations
│   │   ├── error_formatter.dart       # Error message formatting
│   │   ├── file_download.dart         # File download (platform)
│   │   ├── formatters.dart            # Number/date formatting
│   │   ├── kyc_validators.dart        # KYC validation rules
│   │   └── statement_formatters.dart  # Statement formatting
│   └── widgets/                       # Reusable UI components
│       ├── async_value_widget.dart    # Async value wrapper
│       ├── aurora_background.dart     # Animated background
│       ├── branded_loading.dart       # Branded loading spinner
│       ├── glass_button.dart          # Glassmorphic button
│       ├── glass_card.dart            # Glassmorphic card
│       ├── glass_text_field.dart      # Glassmorphic text field
│       ├── glassmorphic_card.dart     # Glassmorphic container
│       ├── hud_navigation.dart        # HUD-style navigation
│       ├── luma_bar.dart              # Luminance-aware bar
│       ├── payment_mode_chips.dart    # Payment mode selector
│       ├── powered_by_badge.dart      # Powered-by badge
│       ├── premium_app_bar.dart       # Custom app bar
│       ├── premium_calendar_sheet.dart # Calendar bottom sheet
│       ├── progress_gauge.dart        # Circular progress
│       ├── shimmer_card.dart          # Shimmer loading card
│       ├── shimmer_loading.dart       # Shimmer loading
│       ├── smokey_background.dart     # Smoky background
│       ├── sparkline_chart.dart       # Mini sparkline chart
│       ├── status_badge.dart          # Status indicator
│       └── update_wrapper.dart        # App update wrapper
│
├── features/
│   ├── admin/                         # Super Admin portal
│   ├── analytics/                     # Analytics dashboards
│   ├── api/                           # API key management
│   ├── auth/                          # Authentication (login, signup, splash, verify)
│   ├── billing/                       # Subscription & invoicing
│   ├── branch_manager/                # Branch Manager portal (12 pages)
│   ├── branches/                      # Branch CRUD
│   ├── branding/                      # White-label branding
│   ├── chatbot/                       # AI-powered floating chatbot
│   ├── collections/                   # Collection audit & backdate
│   ├── customer_portal/               # Customer self-service (14 pages)
│   ├── growth/                        # Growth analytics models
│   ├── home/                          # Executive Admin dashboard
│   ├── invitations/                   # Org invitation system
│   ├── loans/                         # Loan management (CRUD + statements)
│   ├── members/                       # Member onboarding
│   ├── operations/                    # Operational utilities
│   ├── payments/                      # Today's payments tracking
│   ├── savings/                       # Savings management (CRUD + statements)
│   ├── settings/                      # Org settings, activity logs, security
│   ├── setup/                         # First-run setup wizard
│   ├── staff/                         # Staff / Collection Agent portal (13 pages)
│   ├── super_admin/                   # Super Admin portal (22 pages)
│   ├── transactions/                  # Transaction history
│   └── users/                         # User management (CRUD, audit, import)
│
├── providers/
│   └── supabase_provider.dart         # Supabase client provider
│
└── router/
    └── app_router.dart                # GoRouter with role-based routing

supabase/                              # Database schema & migrations
├── migrations/                        # Timestamped SQL migrations
├── *.sql                              # Schema, RLS policies, triggers, fixes

test/                                  # Unit, widget, and integration tests
├── core/services/                     # SMS service tests
├── core/providers/                    # Provider tests
├── unit/models/                       # Model unit tests
├── unit/utils/                        # Utility tests
└── widget/                            # Widget smoke tests
```

---

## Database Schema

### Core Tables

| Table | Purpose |
|-------|---------|
| `profiles` | User profiles (admin, staff, customer) with role-based access |
| `members` | Customer/member profiles with KYC status |
| `loans` | Loan applications with status lifecycle (draft → submitted → approved → active → closed) |
| `emi_schedule` | EMI repayment schedule per loan |
| `savings` | Savings plans with target amounts and maturity |
| `savings_installments` | Individual savings deposit records |
| `transactions` | All financial transactions (disbursements, payments, deposits, withdrawals) |
| `collections` | Field collection records with GPS coordinates |
| `branches` | Branch office locations |

### Staff Portal Tables

| Table | Purpose |
|-------|---------|
| `staff_profiles` | Staff details, branch assignment |
| `staff_wallets` | Cash-in-hand tracking per agent |
| `staff_locations` | GPS location history |
| `staff_streaks` | Daily collection streak tracking |
| `staff_breaks` | Work time break logging |
| `visits` | Customer visit records with GPS |
| `cash_deposits` | Branch deposit records |
| `collection_targets` | Daily/weekly/monthly targets |
| `activity_logs` | Complete audit trail |
| `sync_queue` | Offline operation queue |
| `achievements` | Gamification badges |
| `leaderboards` | Performance rankings |

### Platform Tables

| Table | Purpose |
|-------|---------|
| `organizations` | Multi-tenant organization registry |
| `org_invitations` | Invitation system for onboarding |
| `org_subscriptions` | Billing and subscription tracking |
| `invoices` | Invoice records |
| `api_keys` | API key management |
| `org_branding` | White-label branding configuration |
| `brand_presets` | Pre-built branding themes |
| `support_tickets` | Customer support tickets |
| `customer_feedback` | Feedback submissions |
| `customer_notifications` | Push notification records |
| `notification_preferences` | Per-user notification settings |
| `sms_outbox` | SMS delivery queue |
| `sms_config` | SMS provider configuration |
| `subscription_plans` | Available subscription tiers |
| `platform_settings` | Global platform configuration |

### Row Level Security (RLS)

All tables have RLS enabled with role-scoped policies:

| Role | Access |
|------|--------|
| **Super Admin** | Full platform access across all organizations |
| **Executive Admin** | Full access within their organization |
| **Branch Manager** | Access scoped to their branch |
| **Staff** | Can only read/update their own data; collections filtered by `staff_id` |
| **Customer** | Can only view their own loans, payments, and savings |

---

## Edge Functions

Supabase Edge Functions (Deno) for server-side operations:

| Function | Purpose |
|----------|---------|
| `send-welcome-email` | Sends welcome email to newly created users via Resend API |
| `chat-proxy` | Proxies AI chatbot requests to NVIDIA NIM API (Llama 3.1 70B) |
| `set-user-password` | Admin endpoint to reset/create user passwords with audit logging |

---

## Scheduled Jobs & Views

### Cron Jobs

| Job | Schedule | Purpose |
|-----|----------|---------|
| `mark_overdue_emis` | Daily at 02:00 | Updates unpaid EMIs past due date to `overdue` status |

### Database Views

| View | Purpose |
|------|---------|
| `staff_today_summary` | Aggregates today's collection stats per staff (collected, cash in hand, digital, streak, target) |
| `overdue_loans_view` | Lists overdue loan schedules with member info, GPS, and assigned staff |
| `analytics_daily_stats` | Materialized view aggregating analytics by org, date, event type |

---

## SMS & Messaging

TRAI/DLT-compliant SMS system with offline outbox support.

### Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│  App Layer  │────▶│  SMS Outbox  │────▶│  Native SMS  │
│  (Flutter)  │     │  (Hive DB)   │     │  (MethodChan)│
└─────────────┘     └──────────────┘     └──────────────┘
       │                   │
       ▼                   ▼
┌─────────────┐     ┌──────────────┐
│  Scheduler  │     │   Supabase   │
│ (WorkManager│     │  sms_outbox  │
└─────────────┘     └──────────────┘
```

### SMS Templates (16 TRAI-compliant)

| Category | Templates |
|----------|-----------|
| **EMI Reminders** | 3 days before, due today, 1 day overdue, overdue with balance, 7+ day escalation |
| **Payment Receipts** | EMI received, loan closed, partial payment |
| **Loan Lifecycle** | Disbursed, application received, rejected |
| **KYC & Account** | KYC reminder, KYC approved, account activation |
| **Promotional** | Top-up offer, referral offer, festival offer (with STOP opt-out) |
| **Field Agent** | Agent collection alert, collection confirmation to member |

### Key SMS Services

| Service | Purpose |
|---------|---------|
| `sms_service.dart` | Native MethodChannel SMS sender with SIM slot selection |
| `sms_outbox_service.dart` | Hive-backed offline outbox queue (pending → sending → sent/failed/dead) |
| `sms_scheduler_service.dart` | WorkManager-based Android scheduler for automated EMI reminders |

---

## Statement Generation

PDF, Excel, and CSV statement generation for both loans and savings.

| Service | Format | Purpose |
|---------|--------|---------|
| `loan_statement_pdf_service.dart` | PDF | Loan statement with amortization schedule |
| `loan_statement_excel_service.dart` | Excel | Loan statement export |
| `loan_statement_csv_service.dart` | CSV | Loan statement export |
| `loan_statement_archive_service.dart` | Archive | Statement archival |
| `savings_statement_pdf_service.dart` | PDF | Savings statement with deposit history |
| `savings_statement_excel_service.dart` | Excel | Savings statement export |
| `savings_statement_csv_service.dart` | CSV | Savings statement export |
| `savings_statement_archive_service.dart` | Archive | Statement archival |
| `customer_statement_service.dart` | PDF | Customer-facing combined statement |

---

## Getting Started

### Prerequisites

- **Flutter SDK** 3.11 or higher
- **Dart SDK** 3.4 or higher
- **Supabase account** (free tier works)
- **Android Studio** / **VS Code** with Flutter extension
- **Git**

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/sansayan01/finance_app_zo.git
   cd finance_app_zo
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment** — see [Environment Variables](#environment-variables)

4. **Set up Supabase database** — see [Database Setup](#database-setup)

5. **Run the app**
   ```bash
   flutter run
   ```

---

## Environment Variables

Create a `.env` file in the project root (copy from `.env.example`):

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# App Configuration
APP_NAME=MicroFlow Pro
APP_VERSION=1.0.0

# Mapbox (for maps)
MAPBOX_ACCESS_TOKEN=pk.your_mapbox_access_token

# Telemetry (optional)
SENTRY_DSN=your-sentry-dsn
POSTHOG_API_KEY=your-posthog-key
POSTHOG_HOST=https://app.posthog.com
```

Or use `--dart-define` flags:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token
```

### Database Setup

Run the following SQL files in your Supabase SQL Editor **in order**:

```bash
# 1. Core schema (members, loans, savings, transactions)
supabase_schema.sql

# 2. Staff portal tables
supabase_staff_schema.sql

# 3. Multi-tenancy (critical for organization isolation)
supabase/fix_staff_multi_tenancy.sql

# 4. RLS policies (critical for security)
supabase/fix_rls_final.sql

# 5. Feature-specific schemas
supabase/customer_portal_schema.sql
supabase/enterprise_schema.sql
supabase/billing_schema.sql
supabase/branding_schema.sql
supabase/branches_schema.sql
supabase/api_schema.sql
supabase/sms_notifications_migration.sql
```

### Running the App

```bash
# Development
flutter run

# Release build
flutter build apk --release
flutter build ios --release

# Web
flutter run -d chrome
```

---

## Offline Support

The staff portal includes full offline capabilities for field operations in areas with poor connectivity.

### Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   UI Layer   │────▶│  Sync Engine │────▶│   Supabase   │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │   Hive DB    │
                     │ (Local Cache)│
                     └──────────────┘
```

### How It Works

| State | Behavior |
|-------|----------|
| **Online** | Operations go directly to Supabase |
| **Offline** | Operations queued in Hive local database |
| **Reconnect** | Background sync processes queue automatically |
| **Conflict** | Last-write-wins with audit log |

### Data Cached Offline

- Staff profile and wallet balance
- Today's EMI collection queue
- Customer list (recent 50)
- Loan details (viewed in last 24h)
- Current collection targets
- Pending operation queue with sync status

### Key Services

| Service | Purpose |
|---------|---------|
| `offline_queue_service.dart` | Manages operation queue persistence |
| `background_sync_service.dart` | Processes queue when connectivity restored |
| `conflict_resolution_service.dart` | Handles data conflicts during sync |
| `duty_auto_resume_service.dart` | Resumes duty status after app restart |

---

## Security

### Authentication

- **Supabase Auth** with email/password
- **Biometric authentication** (fingerprint/face) via `local_auth`
- Session management with automatic token refresh

### Authorization

- **Role-Based Access Control (RBAC)** with 5 roles
- **Row Level Security (RLS)** enforced at database level
- **Route guards** in GoRouter prevent unauthorized navigation

### Data Protection

- API keys stored in environment variables, never hardcoded
- GPS data encrypted at rest
- No images/audio stored (metadata only)
- `.env` files excluded via `.gitignore`

### Audit Trail

- All actions logged in `activity_logs` table
- Each entry includes: timestamp, user, action, entity, metadata
- Immutable records (no deletion, only archival)

---

## Testing

### Test Structure

```
test/
├── core/
│   ├── providers/sms_provider_test.dart
│   └── services/
│       ├── sms_outbox_service_test.dart
│       └── sms_service_test.dart
├── unit/
│   ├── models/
│   │   ├── loan_model_test.dart
│   │   ├── savings_model_test.dart
│   │   └── user_model_test.dart
│   ├── today_payments_provider_test.dart
│   └── utils/formatters_test.dart
├── widget/
│   └── smoke_test.dart
├── matchers.dart
├── test_config.dart
└── test_helpers.dart
```

### Running Tests

```bash
# Unit tests
flutter test

# Widget tests
flutter test test/widget/

# Integration tests
flutter test integration_test/
```

---

## Code Statistics

| Metric | Count |
|--------|-------|
| **Total Dart Files** | 371 |
| **Feature Modules** | 25 |
| **Pages/Screens** | 109 |
| **Widget Components** | 60+ |
| **Services** | 29 |
| **Repositories** | 31 |
| **Data Models** | 41 |
| **Riverpod Providers** | 68 |
| **SQL Schema Files** | 55+ |
| **Edge Functions** | 3 |
| **SMS Templates** | 16 |
| **Test Files** | 13 |

### Pages by Portal

| Portal | Pages |
|--------|-------|
| Super Admin | 22 |
| Executive Admin | 26 |
| Branch Manager | 12 |
| Staff / Collection Agent | 13 |
| Customer Portal | 14 |
| Settings / Core | 10 |
| Auth / Setup | 5 |
| Billing | 3 |
| Invitations | 2 |
| **Total** | **~109** |

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `flutter analyze` before committing
- Write tests for new features
- Use the feature-first directory structure
- Keep providers scoped to their feature module

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## Author

**Sayan** — [@sansayan01](https://github.com/sansayan01)

---

<div align="center">
  <p>Built with ❤️ for MFI Field Collectors</p>
  <p>&copy; 2024-2026 MicroFlow Pro</p>
</div>
