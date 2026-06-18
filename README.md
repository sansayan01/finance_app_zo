<div align="center">

# 🏦 MicroFlow Pro

### *Premium Micro-Finance Management Ecosystem*

<img src="https://img.shields.io/badge/flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
<img src="https://img.shields.io/badge/supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=black" alt="Supabase"/>
<img src="https://img.shields.io/badge/dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"/>
<img src="https://img.shields.io/badge/MIT_License-green?style=for-the-badge" alt="License"/>
<img src="https://img.shields.io/badge/v1.0.1-blue?style=for-the-badge" alt="Version"/>

---

#### 👤 Who is this for?
| Role | Icon | What they do |
|------|------|:---:|
| **Super Admin** | 👑 | Controls the entire platform |
| **Executive Admin** | 🏢 | Runs one organization |
| **Branch Manager** | 🏗️ | Manages one branch |
| **Staff Agent** | 📱 | Collects money in the field |
| **Customer** | 👤 | Gets loans & saves money |

</div>

---

## 🗺️ Navigation Map

```
┌──────────────────────────────────────────────────────────────────┐
│  📖  OVERVIEW        →  Section 1                                │
│  🏗️  ARCHITECTURE    →  Section 2                                │
│  👑  PORTALS         →  Section 3  (5 roles × multiple pages)    │
│  💻  TECH STACK      →  Section 4                                │
│  🗄️  DATABASE        →  Section 5                                │
│  📁  PROJECT MAP     →  Section 6                                │
│  🌤️  EDGE FUNCTIONS  →  Section 7                                │
│  📅  SCHEDULED JOBS  →  Section 8                                │
│  💬  SMS ENGINE      →  Section 9                                │
│  📄  STATEMENTS      →  Section 10                               │
│  🚀  GET STARTED     →  Section 11                               │
│  🔐  SECURITY        →  Section 12                               │
│  📱  OFFLINE MODE    →  Section 13                               │
│  🧪  TESTING         →  Section 14                               │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📖 1. OVERVIEW

<div align="center">

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   🏦 MicroFlow Pro                                         │
│                                                             │
│   A cross-platform app that manages:                       │
│                                                             │
│      💰  Loans  →  Borrow → Repay → Close                 │
│      🐷  Savings →  Deposit → Grow → Withdraw             │
│      📋  Collections →  Track → GPS → Receipt             │
│      👥  Members →  Onboard → KYC → Manage                │
│                                                             │
│   Works ONLINE and OFFLINE 💪                              │
│   Built with Flutter + Supabase                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

</div>

### ⭐ What makes it awesome?

| Feat | Badge | Value |
|------|-------|:-----:|
| Cross-platform | <img src="https://img.shields.io/badge/Android_iOS_Web-3DDC84?style=flat-square&logo=android&logoColor=white" /> | 1 codebase → all devices |
| Offline-first | <img src="https://img.shields.io/badge/Offline_Ready-FF6F00?style=flat-square" /> | Works in rural areas |
| 5 User Roles | <img src="https://img.shields.io/badge/5_Roles-9C27B0?style=flat-square" /> | Super Admin → Customer |
| 109 Pages | <img src="https://img.shields.io/badge/109_Pages-2196F3?style=flat-square" /> | Complete feature coverage |
| SMS Engine | <img src="https://img.shields.io/badge/SMS_16_TS-4CAF50?style=flat-square" /> | TRAI/DLT compliant |
| AI Chatbot | <img src="https://img.shields.io/badge/AI_Bot-FF5722?style=flat-square" /> | Floating, draggable |
| GPS Tracking | <img src="https://img.shields.io/badge/GPS-Lime?style=flat-square&logo=google-maps&logoColor=black" /> | Field geo-tagging |
| Gamification | <img src="https://img.shields.io/badge/Streaks_Achievements-FFD700?style=flat-square" /> | Motivate agents |

---

## 🏗️ 2. ARCHITECTURE

```
╔══════════════════════════════════════════════════════════════╗
║                    APP LAYERS                                 ║
╠══════════════════════════════════════════════════════════════╣
║  👁️  PRESENTATION LAYER                                      ║
║  Pages ──▶ Widgets ──▶ Providers (Riverpod State)            ║
╠══════════════════════════════════════════════════════════════╣
║  🧠 DATA LAYER                                               ║
║  Repositories ──▶ Services ──▶ Models ──▶ Local DB (Hive)   ║
╠══════════════════════════════════════════════════════════════╣
║  ☁️  BACKEND (Supabase)                                       ║
║  PostgreSQL ──▶ RLS Policies ──▶ Edge Functions (Deno)       ║
╠══════════════════════════════════════════════════════════════╣
║  📱 LOCAL DEVICE                                              ║
║  SharedPreferences ──▶ Hive (Offline Cache)                  ║
╚══════════════════════════════════════════════════════════════╝

  State: Riverpod 2.6
  Routes:  GoRouter 14.6
  Icons:  Cupertino Icons
```

---

## 👑 3. THE 5 PORTALS — *Every Single Page*

```
     ┌─────────────────────────────────────────────────────────┐
     │         5 PORTALS × 109 PAGES = MicroFlow Pro           │
     └─────────────────────────────────────────────────────────┘
```

### 👑👑 3.1 SUPER ADMIN PORTAL  *(Platform Owner)*

```
🔒 FULL ACCESS — Every Organization, Every Branch
```

| 🔢 | Page | 📋 What it does |
|:--:|------|----------------|
| 1 | `super_admin_dashboard` | 📊 Platform-wide stats overview |
| 2 | `organizations_management` | 🏢 Create / manage / suspend orgs |
| 3 | `users_management` | 👥 Platform user management |
| 4 | `platform_analytics` | 📈 Cross-org analytics & reports |
| 5 | `platform_settings` | ⚙️ Global platform configuration |
| 6 | `platform_health` | 🏥 System health monitoring |
| 7 | `platform_map` | 🗺️ Geographic distribution view |
| 8 | `security_scorecard` | 🛡️ Security posture assessment |
| 9 | `feature_flags` | 🚩 Feature toggle management |
| 10 | `feature_adoption` | 📊 Feature usage analytics |
| 11 | `audit_logs` | 📜 Platform-wide audit trail |
| 12 | `report_center` | 📑 Centralized report generation |
| 13 | `support_tickets` | 🎫 Support ticket management |
| 14 | `notification_center` | 🔔 Platform notifications |
| 15 | `announcements` | 📢 System-wide announcements |
| 16 | `background_jobs` | ⏱️ Scheduled job monitoring |
| 17 | `onboarding_management` | 🚪 Org onboarding workflows |
| 18 | `maintenance` | 🔧 Maintenance mode controls |
| 19 | `nps_survey` | 📝 Net Promoter Score surveys |
| 20 | `system_controls` | 🎛️ System-level controls |
| 21 | `executive_summary` | 📋 Executive dashboard |
| 22 | `revenue_reconciliation` | 💸 Revenue tracking & reconciliation |

---

### 🏢 3.2 EXECUTIVE ADMIN PORTAL  *(Organization Boss)*

```
📊 Full control of one organization
```

| 🔢 | Page | 📋 What it does |
|:--:|------|----------------|
| 1 | `home_page` | 📊 Dashboard with real-time stats & trends |
| 2 | `loans_page` | 💰 Loan list with status tracking |
| 3 | `loan_detail_page` | 🔍 Individual loan + EMI schedule |
| 4 | `new_loan_page` | ➕ Create a new loan |
| 5 | `edit_loan_page` | ✏️ Edit existing loan |
| 6 | `savings_page` | 🐷 Savings plan management |
| 7 | `saving_detail_page` | 🔍 Individual savings details |
| 8 | `new_recurring_saving_page` | ➕ Create recurring savings plan |
| 9 | `edit_savings_vault_page` | ✏️ Edit savings vault |
| 10 | `users_page` | 👥 Staff & branch manager management |
| 11 | `new_user_page` | ➕ Create new staff users |
| 12 | `user_details_page` | 👤 Staff profile & performance |
| 13 | `user_audit_page` | 📜 User activity audit |
| 14 | `org_chart_page` | 🏗️ Organizational hierarchy chart |
| 15 | `bulk_import_members_page` | 📦 Bulk member onboarding |
| 16 | `member_onboarding_page` | 👤 Individual member onboarding |
| 17 | `analytics_page` | 📊 Collection & performance analytics |
| 18 | `transactions_page` | 💳 Transaction history |
| 19 | `search_page` | 🔍 Global search |
| 20 | `notifications_page` | 🔔 Notification center |
| 21 | `branch_management_page` | 🏢 Branch office management |
| 22 | `today_payments_page` | 📅 Today's payment overview |
| 23 | `billing_page` | 💳 Subscription & billing |
| 24 | `invoices_page` | 📄 Invoice management |
| 25 | `usage_limits_page` | 📊 Usage limit monitoring |
| 26 | `branding_settings_page` | 🎨 White-label branding |

---

### 🏗️ 3.3 BRANCH MANAGER PORTAL  *(Branch Leader)*

```
📍 Manages one branch + sees staff performance
```

| 🔢 | Page | 📋 What it does |
|:--:|------|----------------|
| 1 | `branch_manager_dashboard` | 📊 Branch stats + staff performance |
| 2 | `branch_collections_page` | 💰 Branch collection tracking |
| 3 | `branch_loans_page` | 💰 Branch loan management |
| 4 | `branch_savings_page` | 🐷 Branch savings management |
| 5 | `branch_members_page` | 👥 Branch member list |
| 6 | `branch_member_detail_page` | 🔍 Individual member details |
| 7 | `branch_users_page` | 👥 Branch staff management |
| 8 | `branch_analytics_page` | 📊 Branch performance analytics |
| 9 | `branch_reports_page` | 📑 Branch report generation |
| 10 | `branch_today_payments_page` | 📅 Today's branch payments |
| 11 | `branch_settings_page` | ⚙️ Branch configuration |
| 12 | `manager_live_map_page` | 🗺️ Real-time staff location map |

---

### 📱 3.4 STAFF / COLLECTION AGENT PORTAL  *(Field Hero)*

```
🏃‍♂️ Collects money on the ground — OFFLINE capable
```

| 🔢 | Page | 📋 What it does |
|:--:|------|----------------|
| 1 | `staff_home_dashboard` | 🏠 Wallet, streak, targets, today's agenda |
| 2 | `staff_today_payments_page` | 📋 Today's EMI collection queue |
| 3 | `collection_form_page` | 📝 Record payment + GPS + payment mode |
| 4 | `staff_user_hub_page` | 👤 Customer search & management |
| 5 | `staff_timeline_page` | 🕐 Activity timeline & history |
| 6 | `staff_map_page` | 🗺️ Live customer locations map |
| 7 | `staff_settings_page` | ⚙️ Staff profile & preferences |
| 8 | `staff_targets_page` | 🎯 Daily / weekly / monthly targets |
| 9 | `visit_checkin_page` | 📍 GPS-tagged visit check-in / check-out |
| 10 | `cash_deposit_page` | 💵 Submit cash collected to branch |
| 11 | `break_logging_page` | ☕ Work break tracking |
| 12 | `pending_operations_page` | ⏳ Offline operation queue |
| 13 | `gamification_dashboard` | 🏆 Streaks, achievements, leaderboards |

---

### 👤 3.5 CUSTOMER PORTAL  *(Self-Service)*

```
📱 Customers check their own loan & savings status
```

| 🔢 | Page | 📋 What it does |
|:--:|------|----------------|
| 1 | `customer_home_page` | 🏠 Dashboard: loans, savings, stats |
| 2 | `customer_loans_page` | 💰 Active loans list |
| 3 | `customer_loan_detail_page` | 🔍 Loan details + repayment schedule |
| 4 | `customer_emi_schedule_page` | 📅 EMI calendar view |
| 5 | `customer_savings_page` | 🐷 Savings plans overview |
| 6 | `customer_savings_detail_page` | 🔍 Individual savings details |
| 7 | `customer_transactions_page` | 💳 Payment history |
| 8 | `customer_notifications_page` | 🔔 Notifications inbox |
| 9 | `customer_support_page` | 🎫 Support ticket creation |
| 10 | `customer_profile_page` | 👤 Profile management |
| 11 | `customer_account_settings_page` | ⚙️ Account settings |
| 12 | `customer_feedback_page` | 💬 Feedback submission |
| 13 | `customer_emi_calculator_page` | 🧮 EMI calculator tool |
| 14 | `customer_receipt_page` | 🧾 Payment receipt view |

---

## 💻 4. TECH STACK

```
┌─────────────────────────────────────────────────────────────────┐
│  FRONTEND (Flutter App)                                        │
├─────────────────┬───────────────────────────────────────────────┤
│ 🔵 Flutter 3.11+│ Cross-platform UI framework                │
│ 🟡 Dart 3.4+    │ Language runtime                           │
│ 🔴 Riverpod 2.6 │ State management                           │
│ 🟢 GoRouter 14.6│ Declarative routing                        │
│ ⚡ Flutter Animate│ Smooth animations                       │
│ 📊 FL Chart     │ Charts & visualizations                   │
│ 📅 Table Calendar│ Calendar widgets                         │
│ 🔤 Google Fonts │ Typography                                │
│ ✨ Shimmer      │ Loading placeholders                      │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  BACKEND (Supabase Cloud)                                       │
├─────────────────┬───────────────────────────────────────────────┤
│ 🟣 Supabase     │ PostgreSQL + Auth + Realtime + Edge Fns    │
│ 🛡️ RLS Policies│ Data isolation per role                   │
│ ⚙️ Postgres Fn  │ Server-side logic in the database         │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  OFFLINE & LOCAL                                               │
├─────────────────┬───────────────────────────────────────────────┤
│ 🗄️ Hive        │ Local database for offline data            │
│ 💾 SharedPrefs  │ Settings, tokens, chatbot position         │
│ 📡 Conn. Plus  │ Network status monitor                     │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  MAPS, LOCATION & MEDIA                                        │
├─────────────────┬───────────────────────────────────────────────┤
│ 🗺️ Mapbox       │ Map rendering & visualization              │
│ 📍 Geolocator   │ GPS location tracking                      │
│ 📷 Image Picker │ Photo handling                             │
│ 🗜️ Compress    │ Image compression                          │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  DOCUMENTS & SHARING                                           │
├─────────────────┬───────────────────────────────────────────────┤
│ 📄 PDF          │ Loan & savings statements                  │
│ 📊 Excel        │ Spreadsheet exports                        │
│ 📋 CSV          │ Data exports                               │
│ 🖨️ Printing    │ Print statements & receipts                │
│ 📤 Share Plus  │ Share receipts                             │
│ 📱 QR Flutter   │ QR code generation                         │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  VOICE, BIOMETRICS & AI                                        │
├─────────────────┬───────────────────────────────────────────────┤
│ 🎙️ Speech→Text │ Voice input for chatbot                   │
│ 🔊 Flutter TTS  │ Text-to-speech output                     │
│ 🔐 Local Auth   │ Fingerprint / Face ID                     │
│ 🤖 AI Chatbot   │ NVIDIA NIM Llama 3.1 70B                 │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  ANALYTICS & MONITORING                                        │
├─────────────────┬───────────────────────────────────────────────┤
│ 🐛 Sentry       │ Error tracking & telemetry                │
│ 📈 PostHog      │ Product analytics                         │
│ 🔋 Battery Plus│ Battery status                            │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  DEV TOOLS                                                     │
├─────────────────┬───────────────────────────────────────────────┤
│ 🧪 Mocktail     │ Mocking for tests                         │
│ ⚙️ Build Runner│ Code generation (Freezed + JSON serial.)   │
│ 🏗️ Freezed     │ Immutable data classes                    │
│ 📋 JSON Ser.    │ JSON serialization                        │
│ 🚗 Flutter Dr.  │ Integration testing                       │
│ 🔍 Flutter Lints│ Static analysis                           │
└─────────────────┴───────────────────────────────────────────────┘
```

---

## 🗄️ 5. DATABASE — *Every Table Explained*

```
┌─────────────────────────────────────────────────────────────────────┐
│                      🗄️ DATABASE TABLES                              │
└─────────────────────────────────────────────────────────────────────┘
```

### 💼 Core Business Tables

| Table | 🔑 Purpose |
|-------|-----------|
| `profiles` | 👤 All users — admin, staff, customer |
| `members` | 🧾 Customer/member profiles + KYC status |
| `loans` | 💰 Loan apps — draft → submitted → approved → active → closed |
| `emi_schedule` | 📅 EMI repayment schedule per loan |
| `savings` | 🐷 Savings plans with target & maturity |
| `savings_installments` | 💵 Individual savings deposit records |
| `transactions` | 💳 ALL financial transactions |
| `collections` | 📍 Field collections with GPS coordinates |
| `branches` | 🏢 Branch office locations |

### 📱 Staff Portal Tables

| Table | 🔑 Purpose |
|-------|-----------|
| `staff_profiles` | 👨‍💼 Staff details + branch assignment |
| `staff_wallets` | 💵 Cash-in-hand tracking per agent |
| `staff_locations` | 📍 GPS location history |
| `staff_streaks` | 🔥 Daily collection streak tracking |
| `staff_breaks` | ☕ Work time break logging |
| `visits` | 🏠 Customer visit records with GPS |
| `cash_deposits` | 💵 Branch deposit records |
| `collection_targets` | 🎯 Daily/weekly/monthly targets |
| `activity_logs` | 📜 Complete audit trail |
| `sync_queue` | ⏳ Offline operation queue |
| `achievements` | 🏆 Gamification badges |
| `leaderboards` | 🥇 Performance rankings |

### 🌐 Platform Tables

| Table | 🔑 Purpose |
|-------|-----------|
| `organizations` | 🏢 Multi-tenant org registry |
| `org_invitations` | ✉️ Invitation system for onboarding |
| `org_subscriptions` | 💳 Billing & subscription tracking |
| `invoices` | 📄 Invoice records |
| `api_keys` | 🔑 API key management |
| `org_branding` | 🎨 White-label branding config |
| `brand_presets` | 🎨 Pre-built branding themes |
| `support_tickets` | 🎫 Customer support tickets |
| `customer_feedback` | 💬 Feedback submissions |
| `customer_notifications` | 🔔 Push notification records |
| `notification_preferences` | ⚙️ Per-user notification settings |
| `sms_outbox` | 📤 SMS delivery queue |
| `sms_config` | ⚙️ SMS provider configuration |
| `subscription_plans` | 📋 Available subscription tiers |
| `platform_settings` | ⚙️ Global platform configuration |

### 🔐 RLS — Security at the Database Level

```
┌─────────────┬──────────────────────────────────────────────────┐
│ Role        │ What they can see / do                          │
├─────────────┼──────────────────────────────────────────────────┤
│ 👑 Super Admin│ Full access across ALL organizations         │
│ 🏢 Exec Admin│ Full access within THEIR organization         │
│ 🏗️ Manager   │ Access scoped to THEIR branch                  │
│ 📱 Staff     │ Own data only; collections filtered by staff_id│
│ 👤 Customer  │ Own loans, payments, and savings only          │
└─────────────┴──────────────────────────────────────────────────┘
```

---

## 📁 6. PROJECT STRUCTURE

```
📦 MicroFlow Pro/
│
├── 📄 supabase_schema.sql          (Core: members, loans, savings, transactions)
├── 📄 supabase_staff_schema.sql    (Staff: wallets, streaks, visits, gamification)
├── 📄 supabase_update_schema.sql   (Schema updates)
├── 🗂️ supabase/                    (50+ SQL files — RLS, fixes, migrations)
├── 🔧 supabase/functions/          (3 Edge Functions)
│
├── 📱 lib/
│   ├── 📄 main.dart                (App entry point)
│   ├── 📄 app.dart                 (MaterialApp config)
│   │
│   ├── ⚙️ core/                    (Shared foundation)
│   │   ├── ⚙️ config/env_config.dart          ← SECRETS go here
│   │   ├── 🎨 constants/
│   │   │   ├── app_colors.dart               ← Color palette
│   │   │   ├── app_spacing.dart              ← Size constants
│   │   │   ├── app_typography.dart           ← Font styles
│   │   │   ├── enums.dart                    ← All enums & statuses
│   │   │   ├── layout.dart                   ← Breakpoints
│   │   │   └── sms_templates.dart            ← 16 SMS templates
│   │   ├── 🧠 models/
│   │   │   ├── statement_org_info.dart
│   │   │   └── system_config.dart
│   │   ├── 🔌 providers/
│   │   │   ├── branding_provider.dart
│   │   │   ├── location_providers.dart
│   │   │   ├── org_provider.dart
│   │   │   ├── sms_config_provider.dart
│   │   │   ├── sms_outbox_provider.dart
│   │   │   ├── sms_provider.dart
│   │   │   ├── storage_providers.dart
│   │   │   └── system_config_provider.dart
│   │   ├── 🔧 services/              (13 services)
│   │   │   ├── app_icon_service.dart       ← Dynamic app icon
│   │   │   ├── app_update_service.dart     ← In-app update checks
│   │   │   ├── avatar_upload_service.dart  ← Avatar management
│   │   │   ├── email_service.dart          ← Email notifications
│   │   │   ├── haptic_service.dart         ← Haptic feedback
│   │   │   ├── image_compress_service.dart ← Image compression
│   │   │   ├── live_location_service.dart  ← Real-time GPS streaming
│   │   │   ├── location_service.dart       ← GPS utilities
│   │   │   ├── offline_queue_service.dart  ← Queue service
│   │   │   ├── sms_outbox_service.dart     ← SMS offline queue
│   │   │   ├── sms_scheduler_service.dart  ← WorkManager scheduler
│   │   │   └── sms_service.dart            ← Native SMS MethodChannel
│   │   ├── 🎨 theme/
│   │   │   ├── app_theme.dart              ← Light/Dark themes
│   │   │   ├── design_system.dart          ← Design tokens
│   │   │   └── theme_provider.dart         ← Theme switching
│   │   ├── 🛠️ utils/                 (7 utilities)
│   │   │   ├── auto_refresh_mixin.dart
│   │   │   ├── calculations.dart
│   │   │   ├── error_formatter.dart
│   │   │   ├── file_download.dart
│   │   │   ├── formatters.dart
│   │   │   ├── kyc_validators.dart
│   │   │   └── statement_formatters.dart
│   │   └── 🧩 widgets/               (23 reusable widgets)
│   │       ├── async_value_widget.dart
│   │       ├── aurora_background.dart
│   │       ├── branded_loading.dart
│   │       ├── glass_button.dart
│   │       ├── glass_card.dart
│   │       ├── glass_text_field.dart
│   │       ├── glassmorphic_card.dart
│   │       ├── hud_navigation.dart
│   │       ├── luma_bar.dart
│   │       ├── payment_mode_chips.dart
│   │       ├── powered_by_badge.dart
│   │       ├── premium_app_bar.dart
│   │       ├── premium_calendar_sheet.dart
│   │       ├── progress_gauge.dart
│   │       ├── shimmer_card.dart
│   │       ├── shimmer_loading.dart
│   │       ├── smokey_background.dart
│   │       ├── sparkline_chart.dart
│   │       ├── status_badge.dart
│   │       └── update_wrapper.dart
│   │
│   ├── 🔌 providers/
│   │   └── supabase_provider.dart           ← Supabase client
│   │
│   ├── 🗺️ router/
│   │   └── app_router.dart                 ← GoRouter with role-based routes
│   │
│   └── ✨ features/                   (19 feature modules)
│       ├── admin/                    ← Super Admin + Dashboard
│       │   ├── admin_dashboard_page.dart
│       │   ├── admin_org_dashboard_page.dart
│       │   ├── admin_org_detail_page.dart
│       │   ├── admin_org_settings_page.dart
│       │   └── trial_banner.dart
│       │
│       ├── analytics/                ← Analytics dashboard
│       │   ├── analytics_models.dart
│       │   ├── analytics_page.dart
│       │   └── analytics_providers.dart
│       │
│       ├── api/                      ← API Key management
│       │   ├── api_key_model.dart
│       │   ├── api_providers.dart
│       │   └── api_repository.dart
│       │
│       ├── auth/                     ← Login / Signup / Splash / Verify
│       │   ├── user_model.dart
│       │   ├── auth_repository.dart
│       │   ├── login_page.dart
│       │   ├── signup_page.dart
│       │   ├── splash_page.dart
│       │   ├── verify_email_page.dart
│       │   └── auth_provider.dart
│       │
│       ├── billing/                  ← Subscriptions & Invoicing
│       │   ├── invoice_model.dart
│       │   ├── org_subscription_model.dart
│       │   ├── subscription_plan_model.dart
│       │   ├── billing_providers.dart
│       │   ├── billing_repository.dart
│       │   ├── billing_page.dart
│       │   ├── invoices_page.dart
│       │   └── usage_limits_page.dart
│       │
│       ├── branches/                 ← Branch CRUD
│       │   ├── branch_model.dart
│       │   ├── branch_providers.dart
│       │   ├── branch_repository.dart
│       │   └── branch_management_page.dart
│       │
│       ├── branch_manager/           ← Branch Manager Portal (12 pages)
│       │   ├── branch_stats_model.dart
│       │   ├── branch_manager_providers.dart
│       │   ├── branch_payment_providers.dart
│       │   ├── branch_scoped_providers.dart
│       │   ├── branch_manager_repository.dart
│       │   ├── branch_analytics_page.dart
│       │   ├── branch_collections_page.dart
│       │   ├── branch_loans_page.dart
│       │   ├── branch_manager_dashboard.dart
│       │   ├── branch_members_page.dart
│       │   ├── branch_member_detail_page.dart
│       │   ├── branch_reports_page.dart
│       │   ├── branch_savings_page.dart
│       │   ├── branch_settings_page.dart
│       │   ├── branch_today_payments_page.dart
│       │   ├── branch_users_page.dart
│       │   └── manager_live_map_page.dart
│       │
│       ├── branding/                 ← White-label theming
│       │   ├── org_branding_model.dart
│       │   ├── branding_providers.dart
│       │   ├── branding_repository.dart
│       │   └── branding_settings_page.dart
│       │
│       ├── chatbot/                  ← 🤖 AI Floating Chatbot
│       │   ├── chat_message.dart
│       │   ├── chatbot_repository.dart
│       │   ├── chat_config_provider.dart
│       │   ├── chat_provider.dart
│       │   └── floating_chatbot.dart      ← Draggable + resizable
│       │
│       ├── collections/              ← Collection audit & backdating
│       │   └── collection_backdate_audit_repository.dart
│       │
│       ├── customer_portal/          ← Customer Self-Service (14 pages)
│       │   ├── (6 models)
│       │   ├── (12 providers)
│       │   ├── (7 repositories)
│       │   ├── (5 services — biometrics, EMI calc, receipts, statements)
│       │   ├── 14 pages (home, loans, savings, transactions, etc.)
│       │   └── 13 widgets (charts, cards, tiles)
│       │
│       ├── growth/                   ← Growth analytics models
│       │   └── growth_models.dart
│       │
│       ├── home/                     ← Executive Admin Dashboard
│       │   ├── dashboard_providers.dart
│       │   ├── notification_providers.dart
│       │   ├── home_page.dart
│       │   ├── notifications_page.dart
│       │   ├── search_page.dart
│       │   ├── staff_home_page.dart
│       │   ├── staff_providers.dart
│       │   └── live_agents_map_card.dart
│       │
│       ├── invitations/              ← ✉️ Org invitation system
│       │   ├── org_invitation_model.dart
│       │   ├── invitation_providers.dart
│       │   ├── invitation_repository.dart
│       │   ├── accept_invitation_page.dart
│       │   └── manage_invitations_page.dart
│       │
│       ├── loans/                    ← 💰 Loan Management
│       │   ├── loan_model.dart
│       │   ├── emi_schedule_model.dart
│       │   ├── loan_providers.dart
│       │   ├── loans_repository.dart
│       │   ├── emi_repository.dart
│       │   ├── loan_statement_pdf_service.dart
│       │   ├── loan_statement_excel_service.dart
│       │   ├── loan_statement_csv_service.dart
│       │   ├── loan_statement_archive_service.dart
│       │   ├── qr_png.dart
│       │   ├── loans_page.dart
│       │   ├── loan_detail_page.dart
│       │   ├── new_loan_page.dart
│       │   ├── edit_loan_page.dart
│       │   ├── collection_sheet.dart
│       │   ├── emi_payment_selector.dart
│       │   └── statement_options_sheet.dart
│       │
│       ├── members/                  ← 👤 Member Onboarding
│       │   ├── member_model.dart
│       │   ├── members_repository.dart
│       │   ├── member_onboarding_page.dart
│       │   ├── member_providers.dart
│       │   └── onboarding_provider.dart
│       │
│       ├── operations/               ← Operational utilities
│       │   └── operations_models.dart
│       │
│       ├── payments/                 ← 💵 Today's Payments
│       │   ├── today_payment_model.dart
│       │   ├── payment_providers.dart
│       │   ├── payment_export.dart
│       │   └── today_payments_page.dart
│       │
│       ├── savings/                  ← 🐷 Savings Management
│       │   ├── savings_model.dart
│       │   ├── savings_installment_model.dart
│       │   ├── savings_providers.dart
│       │   ├── savings_repository.dart
│       │   ├── savings_statement_pdf_service.dart
│       │   ├── savings_statement_excel_service.dart
│       │   ├── savings_statement_csv_service.dart
│       │   ├── savings_statement_archive_service.dart
│       │   ├── savings_statement_models.dart
│       │   ├── savings_page.dart
│       │   ├── saving_detail_page.dart
│       │   ├── new_recurring_saving_page.dart
│       │   ├── edit_savings_vault_page.dart
│       │   ├── new_recurring_saving_provider.dart
│       │   └── savings_payment_selector.dart
│       │
│       ├── settings/                 ← ⚙️ Org & App Settings
│       │   ├── activity_log_model.dart
│       │   ├── brand_model.dart
│       │   ├── activity_logs_provider.dart
│       │   ├── activity_log_repository_provider.dart
│       │   ├── brand_provider.dart
│       │   ├── activity_log_repository.dart
│       │   ├── activity_logs_page.dart
│       │   ├── app_update_page.dart
│       │   ├── integrations_settings_page.dart
│       │   ├── organization_profile_page.dart
│       │   ├── organization_settings_page.dart
│       │   ├── profile_page.dart
│       │   ├── security_compliance_page.dart
│       │   ├── settings_page_v2.dart
│       │   ├── settings_provider.dart
│       │   └── icon_preset_picker.dart
│       │
│       ├── setup/                    ← 🚀 First-run Setup Wizard
│       │   ├── setup_provider.dart
│       │   └── setup_wizard_page.dart
│       │
│       ├── staff/                    ← 📱 Staff Portal (13 pages)
│       │   ├── (8 models)  — staff_profile, collection, streak, wallet,
│       │   │                   achievement, leaderboard, target, audit_log
│       │   ├── (9 providers) — collections, duty, gamification,
│       │   │                    live_tracking, sms, staff_branch, map, sync, visits
│       │   ├── (5 repositories) — collection, duty, gamification,
│       │   │                       live_tracking, staff
│       │   ├── (5 services) — background_sync, conflict_resolution,
│       │   │                   duty_auto_resume, local_database,
│       │   │                   offline_sync_engine, security_service
│       │   ├── (1 utils) — collection_backdate_rbac
│       │   ├── 13 pages
│       │   └── 17 widgets
│       │
│       ├── super_admin/              ← 👑 Super Admin Portal (22 pages)
│       │   ├── super_admin_models.dart
│       │   ├── super_admin_providers.dart
│       │   ├── super_admin_repository.dart
│       │   ├── 22 page files
│       │   └── super_admin_shell.dart
│       │
│       ├── transactions/             ← 💳 Transaction History
│       │   ├── transaction_model.dart
│       │   ├── transactions_repository.dart
│       │   └── transactions_page.dart
│       │
│       └── users/                    ← 👥 User Management
│           ├── csv_utils.dart
│           ├── user_repository.dart
│           ├── bulk_import_members_page.dart
│           ├── new_user_page.dart
│           ├── org_chart_page.dart
│           ├── users_page.dart
│           ├── user_audit_page.dart
│           ├── user_details_page.dart
│           ├── admin_user_actions_provider.dart
│           ├── avatar_provider.dart
│           ├── new_user_provider.dart
│           └── user_list_provider.dart
│
└── 📂 test/                         ← Test files
    ├── core/providers/
    ├── core/services/
    ├── unit/models/
    ├── unit/utils/
    └── widget/
```

---

## 🌤️ 7. EDGE FUNCTIONS  *(Supabase Server-Side)*

```
Cloud functions running on Deno runtime via Supabase
```

| # | Function | 🔑 Purpose | AI? |
|:-:|----------|-----------|:---:|
| 1 | `send-welcome-email` | ✉️ Sends welcome email to new users via Resend API | ❌ |
| 2 | `chat-proxy` | 🤖 Proxies AI chatbot → NVIDIA NIM (Llama 3.1 70B) | ✅ |
| 3 | `set-user-password` | 🔑 Admin endpoint to reset/create passwords + audit log | ❌ |

### Chatbot in action:

```
┌─────────────────────────────────────────────────────────┐
│  User types message in chatbot                           │
│       │                                                  │
│       ▼                                                  │
│  Flutter App ──▶ chat_provider.dart                     │
│       │                                                  │
│       ▼                                                  │
│  Supabase Edge Function: chat-proxy                     │
│       │                                                  │
│       ▼                                                  │
│  NVIDIA NIM API (Llama 3.1 70B)                        │
│       │                                                  │
│       ▼                                                  │
│  Response streams back to user                          │
│                                                         │
│  👉 Floating chatbot is DRAGGABLE & PERSISTS position   │
└─────────────────────────────────────────────────────────┘
```

---

## ⏱️ 8. SCHEDULED JOBS & DATABASE VIEWS

### Cron Jobs *(run automatically)*

| Job | ⏰ Schedule | 🔑 Purpose |
|-----|------------|-----------|
| `mark_overdue_emis` | Daily @ 02:00 | Updates unpaid EMIs past due date → **overdue** |

### Database Views *(pre-computed queries)*

| View | 🔑 Purpose |
|------|-----------|
| `staff_today_summary` | Today's collection stats per agent (collected, cash, digital, streak, target) |
| `overdue_loans_view` | Overdue loan schedules + member info + GPS + assigned staff |
| `analytics_daily_stats` | Daily analytics aggregated by org, date, event type |

---

## 💬 9. SMS ENGINE

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│   📱 App     │──▶│  📤 Outbox   │──▶│  📲 Native   │
│  (Flutter)   │   │  (Hive DB)   │   │    SMS       │
└──────────────┘   └──────────────┘   └──────────────┘
       │                 │                  │
       │                 ▼                  │
       │          ┌──────────────┐          │
       │          │ ⏱️ Scheduler │          │
       │          │  (WorkManager│          │
       │          └──────────────┘          │
       │                                    │
       ▼                                    ▼
┌──────────────┐                   ┌──────────────┐
│   Supabase   │                   │   sms_outbox  │
│              │                   │  (PostgreSQL) │
└──────────────┘                   └──────────────┘
```

### 📱 16 TRAI-Compliant SMS Templates

```
┌───────────────────────────────────────────────────────────────────┐
│  EMI REMINDERS 💰                                                  │
│  1. 🔔 3 days before EMI due                                        │
│  2. 🔔 Due today reminder                                           │
│  3. ⚠️ 1 day overdue                                                │
│  4. ⚠️ Overdue with balance (customizable)                          │
│  5. 🚨 7+ days escalation                                           │
├───────────────────────────────────────────────────────────────────┤
│  PAYMENT RECEIPTS 🧾                                               │
│  6. ✅ EMI received                                                 │
│  7. ✅ Loan closed                                                  │
│  8. ✅ Partial payment received                                     │
├───────────────────────────────────────────────────────────────────┤
│  LOAN STORY 📋                                                    │
│  9. 🎉 Application received                                         │
│  10. ✅ Disbursed notification                                      │
│  11. ❌ Rejected notification                                       │
├───────────────────────────────────────────────────────────────────┤
│  KYC & ACCOUNT 🪪                                                  │
│  12. 📋 KYC reminder                                                │
│  13. ✅ KYC approved                                                │
│  14. ✅ Account activated                                           │
├───────────────────────────────────────────────────────────────────┤
│  PROMOTIONAL 🎊                                                    │
│  15. 💰 Top-up offer                                               │
│  16. 👥 Referral offer                                              │
│  17. 🎉 Festival offer (+ STOP opt-out)                             │
├───────────────────────────────────────────────────────────────────┤
│  FIELD AGENT 📍                                                    │
│  18. 👔 Agent collection alert                                      │
│  19. ✅ Collection confirmation to member                           │
└───────────────────────────────────────────────────────────────────┘
```

### SMS Services

| Service | 🔑 Purpose |
|---------|-----------|
| `sms_service.dart` | Native MethodChannel SMS sender + SIM slot selection |
| `sms_outbox_service.dart` | Hive-backed offline queue: pending → sending → sent/failed/dead |
| `sms_scheduler_service.dart` | WorkManager-based Android scheduler for automated EMI reminders |

---

## 📄 10. STATEMENT GENERATION

```
Export financial data in 4 formats for Loans & Savings
```

### Loan Statements

| Service | 📊 Format | 🔑 Purpose |
|---------|----------|-----------|
| `loan_statement_pdf_service` | 📄 PDF | Loan statement + amortization schedule |
| `loan_statement_excel_service` | 📊 Excel | Loan statement export |
| `loan_statement_csv_service` | 📋 CSV | Loan statement export |
| `loan_statement_archive_service` | 🗄️ Archive | Statement archival |

### Savings Statements

| Service | 📊 Format | 🔑 Purpose |
|---------|----------|-----------|
| `savings_statement_pdf_service` | 📄 PDF | Savings statement + deposit history |
| `savings_statement_excel_service` | 📊 Excel | Savings statement export |
| `savings_statement_csv_service` | 📋 CSV | Savings statement export |
| `savings_statement_archive_service` | 🗄️ Archive | Statement archival |

### Customer Statement

| Service | 📊 Format | 🔑 Purpose |
|---------|----------|-----------|
| `customer_statement_service` | 📄 PDF | Customer-facing combined statement |

---

## 🚀 11. GETTING STARTED

### Prerequisites Check

```
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ 📱 Flutter│  │ 🟠 Dart  │  │ ☁ Supabase│  │ 💻 IDE   │
│  3.11+   │  │  3.4+   │  │  (free)  │  │ AS / VSC │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
       ✅            ✅            ✅            ✅
```

### Step-by-step Installation

```bash
# 1️⃣ Clone the repo
git clone https://github.com/sansayan01/finance_app_zo.git
cd finance_app_zo

# 2️⃣ Install dependencies
flutter pub get

# 3️⃣ Set up environment
cp .env.example .env
# Edit .env with your Supabase credentials

# 4️⃣ Run Supabase SQL (in order):
#    supabase_schema.sql          ← Core tables
#    supabase_staff_schema.sql    ← Staff tables
#    fix_staff_multi_tenancy.sql  ← Multi-tenancy (CRITICAL)
#    fix_rls_final.sql            ← RLS policies (CRITICAL)
#    + 50 more migration files

# 5️⃣ Run the app!
flutter run
```

### Build Commands

| Command | 🔑 What it does |
|---------|----------------|
| `flutter run` | 🔧 Development mode |
| `flutter run -d chrome` | 🌐 Web browser |
| `flutter build apk --release` | 🤖 Android APK |
| `flutter build ios --release` | 🍎 iOS IPA |

---

## 🔐 12. SECURITY

```
┌─────────────────────────────────────────────────────────────────┐
│  🔐 SECURITY LAYERS                                             │
├─────────────────────────────────────────────────────────────────┤
│  🔑 AUTHENTICATION                                              │
│     • Supabase Auth (email/password)                            │
│     • Biometric (fingerprint/face) via local_auth               │
│     • Auto token refresh                                        │
│                                                                 │
│  🛡️ AUTHORIZATION                                              │
│     • 5-role RBAC (Riverpod guards)                            │
│     • Row Level Security at DB level (PostgreSQL)              │
│     • Route guards (GoRouter)                                   │
│                                                                 │
│  🔒 DATA PROTECTION                                             │
│     • API keys in .env (NEVER hardcoded)                       │
│     • GPS data encrypted at rest                               │
│     • No images/audio stored (metadata only)                    │
│     • .gitignore blocks all .env files                         │
│                                                                 │
│  📜 AUDIT TRAIL                                                │
│     • Every action logged in activity_logs                     │
│     • Timestamp + user + action + entity + metadata            │
│     • Immutable records (no deletion)                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📱 13. OFFLINE MODE  *(Works in the middle of nowhere)*

```
┌─────────────────────────────────────────────────────────────────┐
│  📶 ONLINE          ───────▶  Supabase (direct)                 │
│  📵 OFFLINE / 🌾 field ───────▶  Hive local database (queue)   │
│  📶 RECONNECTED     ───────▶  Background auto-sync (clears)    │
│  ⚡ CONFLICT        ───────▶  Last-write-wins + audit log       │
└─────────────────────────────────────────────────────────────────┘
```

### Data stored OFFLINE on the device

| Data | 💾 Where |
|------|--------|
| Staff profile & wallet | Hive |
| Today's EMI collection queue | Hive |
| Recent 50 customers | Hive |
| Last 24h loan details | Hive |
| Collection targets | Hive |
| Pending operations | Hive |
| SMS queue | Hive |

### Offline Services

| Service | 🔑 Purpose |
|---------|-----------|
| `offline_queue_service.dart` | Manages operation queue persistence |
| `background_sync_service.dart` | Processes queue when connectivity restored |
| `conflict_resolution_service.dart` | Handles data conflicts during sync |
| `duty_auto_resume_service.dart` | Resumes duty status after app restart |

---

## 🧪 14. TESTING

```
test/
├── core/providers/         ← SMS provider tests
├── core/services/          ← SMS outbox & SMS service tests
├── unit/models/            ← Loan, savings, user model tests
├── unit/utils/             ← Formatter utility tests
└── widget/                 ← Smoke tests
```

### Running Tests

| Command | 🔑 Purpose |
|---------|-----------|
| `flutter test` | 🧪 All unit tests |
| `flutter test test/widget/` | 🧪 Widget smoke tests |
| `flutter test integration_test/` | 🧪 End-to-end tests |

---

## 📊 15. CODE STATISTICS

```
┌────────────────────┬────────┐
│ Metric             │ Count  │
├────────────────────┼────────┤
│ 📄 Total Files     │  371   │
│ ✨ Feature Modules │   25   │
│ 📱 Pages/Screens   │  109   │
│ 🧩 Reusable Widgets│   60+  │
│ 🔧 Services        │   29   │
│ 🏛️ Repositories    │   31   │
│ 🧠 Data Models     │   41   │
│ ⚡ Riverpod Provs  │   68   │
│ 🗄️ SQL Files       │   55+  │
│ ☁️ Edge Functions  │    3   │
│ 📨 SMS Templates   │   16   │
│ 🧪 Test Files      │   13   │
└────────────────────┴────────┘
```

### Page Breakdown by Portal

```
👑  Super Admin    ████████████████░░░░░░░░░░  22 pages
🏢  Executive Admin██████████████████████░░░░░  26 pages
🏗️  Branch Manager ██████████████░░░░░░░░░░░░░  12 pages
📱  Staff Agent    ███████████████░░░░░░░░░░░░  13 pages
👤  Customer       ████████████████░░░░░░░░░░░  14 pages
⚙️  Settings/Core  ████████░░░░░░░░░░░░░░░░░░  10 pages
🔐  Auth/Setup     ██████░░░░░░░░░░░░░░░░░░░░░   5 pages
💳  Billing        ████░░░░░░░░░░░░░░░░░░░░░░░   3 pages
✉️  Invitations    ██░░░░░░░░░░░░░░░░░░░░░░░░░   2 pages
────────────────────────────────────────────────
📊  TOTAL         ████████████████████████░░   ~109 pages
```

---

## 🎨 WIDGET SHOWCASE

```
┌─────────────────────────────────────────────────────────────────────┐
│  🧩 23 REUSABLE WIDGETS (core/widgets/)                              │
├────────────────┬────────────────────────────────────────────────────┤
│ async_value_widget    │ Handles async loading/error/success states   │
│ aurora_background     │ Animated aurora gradient background          │
│ branded_loading       │ Branded loading spinner                      │
│ glass_button          │ Glassmorphic button                          │
│ glass_card            │ Glassmorphic card container                  │
│ glass_text_field      │ Glassmorphic text input                      │
│ glassmorphic_card     │ Frosted glass card effect                    │
│ hud_navigation        │ HUD-style navigation bar                     │
│ luma_bar              │ Luminance-aware bar                          │
│ payment_mode_chips    │ Payment mode selector (cash/UPI/bank)        │
│ powered_by_badge      │ "Powered by" badge                           │
│ premium_app_bar       │ Custom app bar                               │
│ premium_calendar_sheet│ Calendar bottom sheet                        │
│ progress_gauge        │ Circular progress indicator                  │
│ shimmer_card          │ Shimmer loading card                         │
│ shimmer_loading       │ Skeleton loading effect                      │
│ smokey_background     │ Smoky particle background                    │
│ sparkline_chart       │ Mini sparkline chart                         │
│ status_badge          │ Status indicator badge                       │
│ update_wrapper        │ App update wrapper                           │
└────────────────┴────────────────────────────────────────────────────┘
```

---

## 🔑 ENUMS & STATUS TYPES

```
👤  UserRole        → superAdmin | executiveAdmin | manager | collectionAgent | customer
💰  LoanStatus      → draft | pending | approved | active | closed | rejected | restructured
📅  EMIStatus       → pending | paid | overdue | waived | pendingPayment
🏦  InterestType    → flat | reducingBalance
🐷  SavingsStatus   → active | paused | matured | withdrawn | cancelled | closed
📆  SavingsFreq     → daily | weekly | monthly
💳  TransactionType → loanDisbursement | emiPayment | savingsDeposit | savingsWithdrawal | penalty | staffCashDeposit | other
💵  PaymentMode     → cash | upi | bankTransfer | cheque | card
👥  CustomerStatus  → active | inactive | blacklisted
🗓️  CollectionFreq  → daily | weekly | monthly | yearly
🪪  KYCStatus       → pending | verified | rejected
⏳  TenureUnit      → days | weeks | months | years
🏢  BranchStatus    → active | inactive | suspended
```

---

## ⚡ SUPER POWER FEATURES

```
┌───────────────────────────────────────────────────────────────┐
│  ⚡ POWER FEATURES — Things that make this app special        │
├──────────────────────────┬────────────────────────────────────┤
│ 🤖 AI Chatbot           │ Floating, draggable, position saves│
│ 🗺️ Live GPS Maps        │ Staff & customer location tracking │
│ 📍 Visit Check-in/out   │ GPS-tagged field visits            │
│ 🔥 Collection Streaks   │ Gamified daily collection goals    │
│ 🏆 Achievements         │ Badges for milestones              │
│ 🥇 Leaderboards         │ Staff performance rankings         │
│ 📵 Offline Mode         │ Full field ops without internet    │
│ 🔄 Auto-Sync            │ Background sync when online        │
│ 📬 19 SMS Templates      │ TRAI/DLT compliant auto-reminders  │
│ 🧾 Receipt Sharing      │ Share payment receipts instantly   │
│ 📄 Statement Generation │ PDF, Excel, CSV + archival        │
│ 🔐 Biometric Login      │ Fingerprint / Face ID unlock       │
│ 🎨 White-label Branding │ Custom org colors, logos, icons    │
│ 🎯 Daily Targets        │ Daily/weekly/monthly collection    │
│ 💵 Wallet Tracking      │ Cash-in-hand per agent             │
│ 🏦 Multi-tenancy        │ Isolated orgs (10,000+ members)    │
│ 📊 Real-time Analytics  │ Live dashboards & reports          │
│ ⚡ Smart Overdue Detect  │ Auto-mark overdue EMIs daily       │
│ ✉️ Invitation System    │ Email org onboarding               │
└──────────────────────────┴────────────────────────────────────┘
```

---

## ⚠️ PRE-LAUNCH CHECKLIST

```
Before going live, verify these things ✅:

[ ] 📵 Test offline collection: record → wait → go online → sync works?
[ ] 📍 Verify GPS permissions work on Android AND iOS
[ ] 🔄 Test sync with 50+ pending operations at once
[ ] 🛡️ Confirm RLS policies in Supabase are enabled on all tables
[ ] 📤 Test receipt sharing (Share Plus)
[ ] 🧪 Run flutter test — all green?
[ ] 📱 Test on real Android & iOS device (not just simulator)
[ ] 🔍 Check no hardcoded API keys in lib/ directory
[ ] 📋 Verify .env is in .gitignore (secrets protected)
[ ] 🗄️ Run all 50+ SQL migration files in Supabase
[ ] 📱 Test biometric auth vs fallback password
[ ] 📨 Test SMS delivery on both Android & iOS
```

---

## 🤝 Contributing

```
1. Fork the repo
2. git checkout -b feature/amazing-feature
3. git commit -m 'Add amazing feature'
4. git push origin feature/amazing-feature
5. Open a Pull Request
```

**Code Rules:**
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Run `flutter analyze` before committing
- Write tests for new features
- Use feature-first directory structure

---

<div align="center">

## 📊 At a Glance

```
   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
   │  Flutter │     │ Supabase │     │  Riverpod│     │ GoRouter │
   │  UI 📱   │────▶│  Cloud ☁│────▶│  State ⚡│────▶│  Routes 🗺│
   └──────────┘     └──────────┘     └──────────┘     └──────────┘
        │                                   │
        ▼                                   ▼
   ┌──────────┐                     ┌──────────┐
   │  Hive 💾 │                     │  Edge ☁  │
   │ Offline  │                     │ Functions│
   └──────────┘                     └──────────┘
```

**MicroFlow Pro** — Built with ❤️ for MFI Field Collectors

*© 2024–2026 MicroFlow Pro | MIT License*

[![GitHub](https://img.shields.io/badge/GitHub-sansayan01/finance_app_zo-181717?style=for-the-badge&logo=github)](https://github.com/sansayan01/finance_app_zo)

</div>
