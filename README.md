<div align="center">

# 🏦 MicroFlow Pro

### *Premium Micro-Finance Management Ecosystem*

<img src="https://img.shields.io/badge/flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
<img src="https://img.shields.io/badge/supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=black" alt="Supabase"/>
<img src="https://img.shields.io/badge/dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"/>
<img src="https://img.shields.io/badge/MIT_License-green?style=for-the-badge" alt="License"/>
<img src="https://img.shields.io/badge/v1.0.2-blue?style=for-the-badge" alt="Version"/>

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
│  🏗️  ARCHITECTURE      →  Section 2                                │
│  👑  PORTALS           →  Section 3  (5 roles × multiple pages)   │
│  💻  TECH STACK        →  Section 4                                │
│  🗄️  DATABASE          →  Section 5                                │
│  📁  PROJECT MAP       →  Section 6                                │
│  🌐  WEB PORTAL        →  Section 7                                │
│  🎬  REMOTION VIDEO    →  Section 8                                │
│  🤖  N8n WORKFLOW      →  Section 9                                │
│  ☁️  EDGE FUNCTIONS    →  Section 10                               │
│  ⏱️  SCHEDULED JOBS    →  Section 11                               │
│  📅  DATABASE VIEWS    →  Section 12                               │
│  💬  SMS ENGINE        →  Section 13                               │
│  📄  STATEMENTS        →  Section 14                               │
│  📱  PUSH NOTIFICATIONS →  Section 15                              │
│  💳  PAYMENTS          →  Section 16                               │
│  🛠️  WHATSAPP          →  Section 17                               │
│  📊  ANALYTICS ENGINE  →  Section 18                               │
│  🚀  GET STARTED       →  Section 19                               │
│  🔐  SECURITY          →  Section 20                               │
│  📱  OFFLINE MODE      →  Section 21                               │
│  🧪  TESTING           →  Section 22                               │
│  📦  CI/CD & DEPLOY    →  Section 23                               │
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
│      📊  Analytics →  Dashboards → Reports → Export       │
│      💬  AI Chatbot →  Floating, draggable, persistent      │
│      📲  Push Notifications →  FCM real-time alerts       │
│      💳  UPI/Payment Links →  Instant digital payments    │
│      📱  WhatsApp →  Automated customer messaging          │
│      🗂️  Google Drive Backup →  Cloud export & restore     │
│                                                             │
│   Works ONLINE and OFFLINE 💪                              │
│   Built with Flutter + Supabase + Firebase                 │
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
| 109+ Pages | <img src="https://img.shields.io/badge/109+_Pages-2196F3?style=flat-square" /> | Complete feature coverage |
| SMS Engine | <img src="https://img.shields.io/badge/SMS_19_Templates-4CAF50?style=flat-square" /> | TRAI/DLT compliant |
| AI Chatbot | <img src="https://img.shields.io/badge/AI_Bot-FF5722?style=flat-square" /> | Floating, draggable, NVIDIA NIM |
| GPS Tracking | <img src="https://img.shields.io/badge/GPS-Lime?style=flat-square&logo=google-maps&logoColor=black" /> | Field geo-tagging + geofence |
| Gamification | <img src="https://img.shields.io/badge/Streaks_Achievements-FFD700?style=flat-square" /> | Motivate agents |
| Push Notifications | <img src="https://img.shields.io/badge/FCM-FF6F00?style=flat-square" /> | Real-time alerts |
| WhatsApp Integration | <img src="https://img.shields.io/badge/WhatsApp-25D366?style=flat-square" /> | Automated customer messaging |
| Google Drive Backup | <img src="https://img.shields.io/badge/Google_Drive-4285F4?style=flat-square" /> | Cloud export & restore |
| White-label | <img src="https://img.shields.io/badge/White--label-9C27B0?style=flat-square" /> | Per-org branding |
| Payment Links | <img src="https://img.shields.io/badge/UPI_Payments-00B8D4?style=flat-square" /> | Stripe/Razorpay ready |

---

## 🏗️ 2. ARCHITECTURE

```
╔══════════════════════════════════════════════════════════════╗
║                    APP LAYERS                                     ║
╠══════════════════════════════════════════════════════════════╣
║  👁️  PRESENTATION LAYER                                            ║
║  Pages ──▶ Widgets ──▶ Providers (Riverpod State)                   ║
╠══════════════════════════════════════════════════════════════╣
║  🧠 DATA LAYER                                                      ║
║  Repositories ──▶ Services ──▶ Models ──▶ Local DB (Hive)        ║
╠══════════════════════════════════════════════════════════════╣
║  ☁️  BACKEND (Supabase + Firebase)                                   ║
║  PostgreSQL ──▶ RLS Policies ──▶ Edge Functions (Deno)         ║
║  Firebase ──▶ FCM Push Notifications ──→ Auth                     ║
╠══════════════════════════════════════════════════════════════╣
║  🌐 WEB PORTAL (Separate React App)                                 ║
║  React + Vite ──▶ Marketing site + landing page                   ║
╠══════════════════════════════════════════════════════════════╣
║  📱 LOCAL DEVICE                                                    ║
║  SharedPreferences ──▶ Hive (Offline Cache)                       ║
║  WorkManager ──▶ SMS Scheduler + Background Sync                  ║
╚══════════════════════════════════════════════════════════════╝

  State: Riverpod 2.6
  Routes: GoRouter 14.6
  Icons: Cupertino Icons
  Auth: Supabase Auth + Firebase Auth
  Maps: Mapbox + Geolocator + Flutter Map
```

---

## 👑 3. THE 5 PORTALS — *Every Single Page*

```
     ┌─────────────────────────────────────────────────────────┐
     │         5 PORTALS × 109+ PAGES = MicroFlow Pro           │
     └─────────────────────────────────────────────────────────┘
```

### 👑👑 3.1 SUPER ADMIN PORTAL  *(Platform Owner)*

```
🔒 FULL ACCESS — Every Organization, Every Branch
```

| 🔢 | Page | 📋 What it does |
|:--:|------|----------------|
| 1 | `super_admin_dashboard` | 📊 Platform-wide stats overview (real-time metrics, top orgs, activity feed) |
| 2 | `organizations_management` | 🏢 Create / manage / suspend / delete orgs |
| 3 | `users_management` | 👥 Platform user management (all roles) |
| 4 | `platform_settings` | ⚙️ Global platform config (SMTP, SMS, Storage, Security, Rate Limits) |
| 5 | `dashboard` | 📈 Rebuilt with time-based greeting, icon badges, stat tiles, revenue section |
| 6 | `settings_page_v2` | ⚙️ Minimal settings (theme toggle + sign-out) |

**Key features:** Frosted glass HUD pill (desktop) + bottom bar (mobile), matching all other portals. Route guards with reactive auth (ref.watch). Searchable org list with status filter chips. Create org bottom sheet dialog. Pull-to-refresh with empty/loading/error states.

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
| 15 | `bulk_import_members_page` | 📦 Bulk member onboarding (CSV) |
| 16 | `member_onboarding_page` | 👤 Individual member onboarding (4-step wizard) |
| 17 | `analytics_page` | 📊 Collection & performance analytics |
| 18 | `transactions_page` | 💳 Transaction history with filters |
| 19 | `search_page` | 🔍 Global search across all entities |
| 20 | `notifications_page` | 🔔 Notification center |
| 21 | `branch_management_page` | 🏢 Branch office CRUD |
| 22 | `today_payments_page` | 📅 Today's payment overview |
| 23 | `billing_page` | 💳 Subscription & billing |
| 24 | `invoices_page` | 📄 Invoice management |
| 25 | `usage_limits_page` | 📊 Usage limit monitoring |
| 26 | `branding_settings_page` | 🎨 White-label branding (colors, logo, icons) |
| 27 | `loan Products page` | 💰 Loan product management (create, edit, templates) |
| 28 | `savings_products_page` | 🐷 Savings product configuration |
| 29 | `product_form_sheet` | 📝 Product creation/editing bottom sheet |

**Key features:** 29 pages, full CRUD on loans/savings/members/users, analytics with charts (FL Chart), bulk CSV import, search, notifications, branch management, white-label branding, product management.

---

### 🏗️ 3.3 BRANCH MANAGER PORTAL  *(Branch Leader)*

```
📍 Manages one branch + sees staff performance
```

| 🔢 | Page | 📋 What it does |
|:--:|------|----------------|
| 1 | `branch_manager_dashboard` | 📊 Branch stats + staff performance + collection rate |
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
| 12 | `manager_live_map_page` | 🗺️ Real-time staff location map with location history sheet |

**Key features:** 12 pages, branch-scoped data access, live GPS map of staff, collection tracking, loan/savings management, analytics, reports.

---

### 📱 3.4 STAFF / COLLECTION AGENT PORTAL  *(Field Hero)*

```
🏃‍♂️ Collects money on the ground — OFFLINE capable
```

| 🔢 | Page | 📋 What it does |
|:--:|------|----------------|
| 1 | `staff_home_dashboard` | 🏠 Wallet, streak, targets, today's agenda, live tracking toggle |
| 2 | `staff_today_payments_page` | 📋 Today's EMI collection queue |
| 3 | `collection_form_page` | 📝 Record payment + GPS + payment mode (cash/UPI/bank/cheque) |
| 4 | `staff_user_hub_page` | 👤 Customer search & management |
| 5 | `staff_timeline_page` | 🕐 Activity timeline & history |
| 6 | `staff_map_page` | 🗺️ Live customer locations map |
| 7 | `staff_settings_page` | ⚙️ Staff profile & preferences |
| 8 | `staff_targets_page` | 🎯 Daily / weekly / monthly targets with progress ring |
| 9 | `visit_checkin_page` | 📍 GPS-tagged visit check-in / check-out with geofence |
| 10 | `cash_deposit_page` | 💵 Submit cash collected to branch |
| 11 | `break_logging_page` | ☕ Work break tracking |
| 12 | `pending_operations_page` | ⏳ Offline operation queue |
| 13 | `gamification_dashboard` | 🏆 Streaks, achievements, leaderboards, weekly performance chart |

**Key features:** 13 pages, 17 widgets (including on-duty toggle, GPS status chip, sync status bar, wallet card, check-in card, target progress ring, leaderboard snapshot, receipt generator, weekly performance chart, break card, live tracking toggle, activity feed timeline, notification bell, duty status card). Full offline mode with background auto-sync. Gamification with streaks, achievements, and leaderboards.

---

### 👤 3.5 CUSTOMER PORTAL  *(Self-Service)*

```
📱 Customers check their own loan & savings status
```

| 🔢 | Page | 📋 What it does |
|:--:|------|----------------|
| 1 | `customer_home_page` | 🏠 Dashboard: loans, savings, stats, quick pay |
| 2 | `customer_loans_page` | 💰 Active loans list |
| 3 | `customer_loan_detail_page` | 🔍 Loan details + repayment schedule |
| 4 | `customer_loan_quick_pay_page` | 💳 Quick EMI payment (UPI) |
| 5 | `customer_emi_schedule_page` | 📅 EMI calendar view |
| 6 | `customer_emi_calculator_page` | 🧮 EMI calculator tool |
| 7 | `customer_savings_page` | 🐷 Savings plans overview |
| 8 | `customer_savings_detail_page` | 🔍 Individual savings details |
| 9 | `customer_transactions_page` | 💳 Payment history with filters |
| 10 | `customer_notifications_page` | 🔔 Notifications inbox |
| 11 | `customer_support_page` | 🎫 Support ticket creation |
| 12 | `customer_profile_page` | 👤 Profile management |
| 13 | `customer_account_settings_page` | ⚙️ Account settings |
| 14 | `customer_feedback_page` | 💬 Feedback submission |
| 15 | `customer_receipt_page` | 🧾 Payment receipt view |

**Key features:** 15 pages, 13 widgets (charts, cards, tiles), biometric auth (fingerprint/face ID), EMI calculator, quick pay via UPI, receipt generation, support tickets, feedback.

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
│ 🗺️ Flutter Map  │ Alternative map rendering                  │
│ 🔤 Google Fonts │ Typography (Inter)                         │
│ ✨ Shimmer      │ Loading placeholders                      │
│ 🔲 Blur         │ Frosted glass / blur effects                │
│ 📱 Mapbox       │ Map rendering & visualization              │
│ 📍 Geolocator   │ GPS location tracking                      │
│ 📷 Image Picker │ Photo handling                             │
│ 🗜️ Compress    │ Image compression                           │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  BACKEND (Supabase + Firebase)                                 │
├─────────────────┬───────────────────────────────────────────────┤
│ 🟣 Supabase     │ PostgreSQL + Auth + Realtime + Edge Fns    │
│ 🔥 Firebase     │ FCM Push Notifications + Auth                 │
│ 🛡️ RLS Policies│ Data isolation per role                       │
│ ⚙️ Postgres Fn  │ Server-side logic in the database         │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  OFFLINE & LOCAL                                               │
├─────────────────┬───────────────────────────────────────────────┤
│ 🗄️ Hive        │ Local database for offline data            │
│ 💾 SharedPrefs  │ Settings, tokens, chatbot position         │
│ 📡 Conn. Plus  │ Network status monitor                     │
│ ⏱️ WorkManager │ Android background scheduler (SMS)         │
│ 🔄 Background Sync│ Auto-sync queue when online           │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  DOCUMENTS & SHARING                                           │
├─────────────────┬───────────────────────────────────────────────┤
│ 📄 PDF          │ Loan & savings statements + receipts       │
│ 📊 Excel        │ Spreadsheet exports (loans, savings, txns) │
│ 📋 CSV          │ Data exports                               │
│ 🖨️ Printing    │ Print statements & receipts                │
│ 📤 Share Plus  │ Share receipts & content                   │
│ 📱 QR Flutter   │ QR code generation (payment links)        │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  MESSAGING & COMMUNICATION                                      │
├─────────────────┬───────────────────────────────────────────────┤
│ 📱 SMS (Native) │ TRAI/DLT compliant, 19 templates            │
│ 💬 WhatsApp     │ Automated customer messaging (service)      │
│ 🔔 Push (FCM)  │ Firebase Cloud Messaging for notifications  │
│ 🤖 AI Chatbot   │ NVIDIA NIM Llama 3.1 70B via Edge Function │
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
│  CLOUD & BACKUP                                                 │
├─────────────────┬───────────────────────────────────────────────┤
│ ☁️ Google Drive │ Backup export & restore from cloud         │
│ 📧 Resend API   │ Transactional emails (welcome, alerts)     │
│ 🔋 Battery Plus│ Battery status monitoring                  │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  ANALYTICS & MONITORING                                        │
├─────────────────┬───────────────────────────────────────────────┤
│ 🐛 Sentry       │ Error tracking & telemetry                │
│ 📈 PostHog      │ Product analytics                         │
│ 📊 Analytics Engine│ Custom analytics (KPIs, trends)      │
│ 🔋 Battery Plus│ Battery status                            │
└─────────────────┴───────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  DEV TOOLS & AUTOMATION                                        │
├─────────────────┬───────────────────────────────────────────────┤
│ 🧪 Mocktail     │ Mocking for tests                         │
│ ⚙️ Build Runner│ Code generation (Freezed + JSON serial.)   │
│ 🏗️ Freezed     │ Immutable data classes                      │
│ 📋 JSON Ser.    │ JSON serialization                        │
│ 🚗 Flutter Dr.  │ Integration testing                       │
│ 🔍 Flutter Lints│ Static analysis                           │
│ 🔄 N8n          │ Workflow automation (chatbot workflow)     │
│ 🎬 Remotion     │ Video production (org setup tutorial)     │
└─────────────────┴───────────────────────────────────────────────┘
```

---

## 🌐 5. WEB PORTAL

A separate React/Vite web portal at `web_portal/` for the marketing landing page and external access.

| File | Purpose |
|------|---------|
| `web_portal/src/App.jsx` | Main React app |
| `web_portal/src/App.css` | Styling |
| `web_portal/index.html` | HTML entry point |
| `web_portal/vite.config.js` | Vite build config |
| `web_portal/public/hero.png` | Hero image asset |

---

## 🎬 6. REMOTION VIDEO PROJECT

Professional org setup tutorial video built with Remotion (React/TypeScript). Used for onboarding and marketing.

| File | Purpose |
|------|---------|
| `videos/exec-admin-org-setup/storyboard_and_direction.md` | Single source of truth for all scenes |
| `videos/exec-admin-org-setup/src/OrgSetupVideo.tsx` | 9-scene React composition matching Flutter app design |

**Video specs:**
- Remotion 4.0.491
- 9 scenes with sequential typing animations
- Pixel 7 portrait mockup (380×760)
- Aurora background + glassmorphic cards
- Pointer/tap guides + confetti/sparkle effects
- Renders in Remotion Studio at `localhost:3000`
- Full MP4 render via detached background process

---

## 🤖 7. N8n WORKFLOW

Chatbot workflow automation via n8n MCP.

| File | Purpose |
|------|---------|
| `n8n/chatbot-workflow.json` | Chatbot automation workflow definition |

**Status:** Workflow published and active in n8n.

---

## ☁️ 8. EDGE FUNCTIONS  *(Supabase Server-Side + Firebase)*

### Supabase Edge Functions (Deno)

| # | Function | 🔑 Purpose | AI? |
|:-:|----------|-----------|:---:|
| 1 | `send-welcome-email` | ✉️ Sends welcome email to new users via Resend API | ❌ |
| 2 | `chat-proxy` | 🤖 Proxies AI chatbot → NVIDIA NIM (Llama 3.1 70B) | ✅ |
| 3 | `set-user-password` | 🔑 Admin endpoint to reset/create passwords + audit log | ❌ |
| 4 | `send-email` | 📧 Transactional email sending (Resend) | ❌ |
| 5 | `send-push-notification` | 🔔 FCM push notification delivery | ❌ |
| 6 | `send-whatsapp` | 💬 WhatsApp Business API messaging | ❌ |
| 7 | `auto-backup` | 💾 Automated database backup | ❌ |
| 8 | `create-payment-link` | 💳 Stripe/Razorpay payment link generation | ❌ |
| 9 | `payment-webhook` | 🔗 Payment gateway webhook handler | ❌ |
| 10 | `google-token-exchange` | 🔑 Google OAuth token exchange (Drive backup) | ❌ |

### Edge Functions Architecture

```
┌──────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  📱 Flutter  │────▶│  Supabase Edge   │────▶│  External APIs  │
│  App         │     │  Functions       │     │  (Resend, NIM,  │
│              │     │  (Deno runtime)  │     │   FCM, WhatsApp, │
└──────────────┘     └──────────────────┘     │   Stripe, Google │
                                               │   Drive, etc.)   │
                                               └─────────────────┘
```

---

## ⏱️ 9. SCHEDULED JOBS & DATABASE VIEWS

### Cron Jobs *(run automatically on Supabase)*

| Job | ⏰ Schedule | 🔑 Purpose |
|-----|------------|-----------|
| `mark_overdue_emis` | Daily @ 02:00 | Updates unpaid EMIs past due date → **overdue** |
| `auto-backup` | Scheduled | Automated database backup via Edge Function |
| `sms_scheduler` | WorkManager | Automated EMI reminder dispatch on Android |

### Database Views *(pre-computed queries)*

| View | 🔑 Purpose |
|------|-----------|
| `staff_today_summary` | Today's collection stats per agent (collected, cash, digital, streak, target) |
| `overdue_loans_view` | Overdue loan schedules + member info + GPS + assigned staff |
| `analytics_daily_stats` | Daily analytics aggregated by org, date, event type |

---

## 📊 10. ANALYTICS ENGINE

| Component | 🔑 Purpose |
|-----------|-----------|
| `analytics_engine.dart` | Core analytics computation engine |
| `analytics_service.dart` | Analytics data service |
| `analytics_models.dart` | Analytics data models |
| `analytics_page.dart` | Full analytics dashboard page |
| `advanced_analytics_page.dart` | Advanced analytics with deeper drill-downs |
| `analytics_providers.dart` | Riverpod providers for analytics data |
| `analytics_engine_models.dart` | Engine-specific data models |

**Features:** Real-time KPI dashboards, disbursement vs collection charts, savings growth trends, delinquency tracking, CSV/JSON export, daily/weekly/monthly aggregation.

---

## 💬 11. SMS ENGINE

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

### 📱 19 TRAI-Compliant SMS Templates

| Category | # | Template |
|----------|:-:|----------|
| **EMI REMINDERS** | 1 | 🔔 3 days before EMI due |
| | 2 | 🔔 Due today reminder |
| | 3 | ⚠️ 1 day overdue |
| | 4 | ⚠️ Overdue with balance (customizable) |
| | 5 | 🚨 7+ days escalation |
| **PAYMENT RECEIPTS** | 6 | ✅ EMI received |
| | 7 | ✅ Loan closed |
| | 8 | ✅ Partial payment received |
| **LOAN STORY** | 9 | 🎉 Application received |
| | 10 | ✅ Disbursed notification |
| | 11 | ❌ Rejected notification |
| **KYC & ACCOUNT** | 12 | 📋 KYC reminder |
| | 13 | ✅ KYC approved |
| | 14 | ✅ Account activated |
| **PROMOTIONAL** | 15 | 💰 Top-up offer |
| | 16 | 👥 Referral offer |
| | 17 | 🎉 Festival offer (+ STOP opt-out) |
| **FIELD AGENT** | 18 | 👔 Agent collection alert |
| | 19 | ✅ Collection confirmation to member |

### SMS Services

| Service | 🔑 Purpose |
|---------|-----------|
| `sms_service.dart` | Native MethodChannel SMS sender + SIM slot selection + auto permission request |
| `sms_outbox_service.dart` | Hive-backed offline queue: pending → sending → sent/failed/dead |
| `sms_scheduler_service.dart` | WorkManager-based Android scheduler for automated EMI reminders |
| `sms_config_provider.dart` | SMS configuration state management |
| `sms_outbox_provider.dart` | SMS outbox state (Riverpod) |
| `sms_provider.dart` | Core SMS provider |

---

## 📱 12. PUSH NOTIFICATIONS (Firebase FCM)

| Component | 🔑 Purpose |
|-----------|-----------|
| `firebase_messaging` | FCM push notification delivery |
| `push_notification_service.dart` | FCM token management + notification handling |
| `push_notification_provider.dart` | Riverpod provider for push notification state |
| `notification_service.dart` | Local notification scheduling |
| `notification_navigation_handler.dart` | Deep-link handling when notifications are tapped |
| `fcm_token_service.dart` | FCM token registration & refresh |

**Features:** FCM token registration, notification routing, deep-link navigation, foreground/background handling.

---

## 💳 13. PAYMENTS (UPI + Payment Links)

| Component | 🔑 Purpose |
|-----------|-----------|
| `payment_gateway_repository.dart` | Payment gateway abstraction (Stripe/Razorpay) |
| `payment_gateway_service.dart` | Payment gateway service |
| `payment_gateway_providers.dart` | Riverpod providers |
| `upi_service.dart` | UPI payment handling |
| `upi_payment_repository.dart` | UPI payment data layer |
| `upi_providers.dart` | UPI state management |
| `upi_confirm_dialog.dart` | UPI confirmation dialog widget |
| `upi_payment_sheet.dart` | UPI payment sheet UI |
| `payment_pdf_service.dart` | Payment receipt PDF generation |
| `payment_export.dart` | Payment data export utilities |
| `today_payments_page.dart` | Today's payment overview |
| `upi_confirmations_page.dart` | UPI confirmation history |
| `payment_order_model.dart` | Payment order data model |
| `upi_payment_request_model.dart` | UPI payment request model |

**Features:** UPI instant payments, payment link generation (Stripe/Razorpay ready), receipt PDF generation, payment confirmation tracking.

---

## 📱 14. WHATSAPP INTEGRATION

| Component | 🔑 Purpose |
|-----------|-----------|
| `whatsapp_service.dart` | WhatsApp Business API messaging service |

**Features:** Automated WhatsApp messaging to customers for reminders, confirmations, and notifications.

---

## 🗂️ 15. GOOGLE DRIVE BACKUP & RESTORE

| Component | 🔑 Purpose |
|-----------|-----------|
| `google_drive_service.dart` | Google Drive API integration |
| `google_drive_provider.dart` | Riverpod provider for Drive state |
| `backup_export_service.dart` | Backup data export to Drive |
| `restore_backup_service.dart` | Restore data from Drive backup |
| `backup_export_provider.dart` | Backup export state management |
| `restore_backup_provider.dart` | Restore state management |
| `google_token_exchange/index.ts` | Edge Function for OAuth token exchange |

**Features:** Full backup export to Google Drive, cloud restore from backup, OAuth token management via Edge Function.

---

## 📄 16. STATEMENT GENERATION

### Loan Statements

| Service | 📊 Format | 🔑 Purpose |
|---------|----------|-----------|
| `loan_statement_pdf_service` | 📄 PDF | Loan statement + amortization schedule |
| `loan_statement_excel_service` | 📊 Excel | Loan statement export |
| `loan_statement_csv_service` | 📋 CSV | Loan statement export |
| `loan_statement_archive_service` | 🗄️ Archive | Statement archival |

### Savings Statements (Portfolio)

| Service | 📊 Format | 🔑 Purpose |
|---------|----------|-----------|
| `portfolio_savings_statement_pdf_service` | 📄 PDF | Portfolio savings statement + deposit history |
| `savings_statement_pdf_service` | 📄 PDF | Individual savings statement |
| `savings_statement_excel_service` | 📊 Excel | Savings statement export |
| `savings_statement_csv_service` | 📋 CSV | Savings statement export |
| `savings_statement_archive_service` | 🗄️ Archive | Statement archival |
| `savings_statement_models.dart` | 📋 Models | Statement data models |

### Customer Statement

| Service | 📊 Format | 🔑 Purpose |
|---------|----------|-----------|
| `customer_statement_service` | 📄 PDF | Customer-facing combined statement |

### Transaction Export

| Service | 📊 Format | 🔑 Purpose |
|---------|----------|-----------|
| `transaction_pdf_service` | 📄 PDF | Transaction history PDF |
| `transaction_excel_service` | 📊 Excel | Transaction history export |
| `transaction_csv_service` | 📋 CSV | Transaction history export |
| `transaction_export_options.dart` | ⚙️ Config | Export options configuration |
| `transaction_export_sheet.dart` | 📤 UI | Export sheet widget |
| `transaction_filter_panel.dart` | 🔍 UI | Transaction filter panel |

---

## 🔐 17. SECURITY (5 Roles × RLS)

```
┌─────────────────────────────────────────────────────────────────┐
│  🔐 SECURITY LAYERS                                             │
├─────────────────────────────────────────────────────────────────┤
│  🔑 AUTHENTICATION                                              │
│     • Supabase Auth (email/password)                           │
│     • Firebase Auth (FCM token)                                │
│     • Biometric (fingerprint/face) via local_auth              │
│     • TOTP 2FA support for admin accounts                      │
│     • Auto token refresh                                         │
│                                                                 │
│  🛡️ AUTHORIZATION                                              │
│     • 5-role RBAC (Riverpod guards)                            │
│     • Row Level Security at DB level (PostgreSQL)              │
│     • Route guards (GoRouter)                                   │
│                                                                 │
│  🔒 DATA PROTECTION                                             │
│     • API keys in .env (NEVER hardcoded)                      │
│     • GPS data encrypted at rest                               │
│     • No images/audio stored (metadata only)                   │
│     • .gitignore blocks all .env files                         │
│                                                                 │
│  📜 AUDIT TRAIL                                                │
│     • Every action logged in activity_logs                     │
│     • Timestamp + user + action + entity + metadata            │
│     • Immutable records (no deletion)                           │
│                                                                 │
│  🔄 OFFLINE SECURITY                                           │
│     • Conflict resolution (last-write-wins + audit log)       │
│     • Background sync with RLS compliance                      │
│     • Duty auto-resume after app restart                       │
└─────────────────────────────────────────────────────────────────┘
```

### RLS Roles

| Role | What they can see / do |
|------|------------------------|
| 👑 Super Admin | Full access across ALL organizations |
| 🏢 Exec Admin | Full access within THEIR organization |
| 🏗️ Manager | Access scoped to THEIR branch |
| 📱 Staff | Own data only; collections filtered by staff_id |
| 👤 Customer | Own loans, payments, and savings only |

---

## 📁 18. PROJECT STRUCTURE — Complete File Map

```
📦 MicroFlow Pro/
│
├── 📄 README.md
├── 📄 SPEC.md                    (Technical specification)
├── 📄 ROADMAP.md                 (SaaS roadmap with phases)
├── 📄 audience.md                (Marketing audience personas)
├── 📄 CLAUDE.md                  (Project instructions & rules)
├── 📄 SETUP.md                   (Setup instructions)
├── 📄 TESTING.md                 (Testing guide)
├── 📄 ADMIN_PORTAL_AUDIT_REPORT.md (Audit findings)
├── 📄 FIX_SUMMARY.md             (Fix summary)
├── 📄 VERIFICATION_REPORT.md     (Verification results)
├── 📄 FIREBASE_APP_DISTRIBUTION_SETUP.md
├── 📄 LIVE_LOCATION_MAP_PLAN.md
├── 📄 PORTAL_DEVELOPMENT_PLAN.md
├── 📄 SaaS_SCALE_PLAN.md
├── 📄 .mcp.json                  (MCP server config)
│
├── 📱 lib/
│   ├── 📄 main.dart                (App entry point)
│   ├── 📄 app.dart                 (MaterialApp config)
│   │
│   ├── ⚙️ core/
│   │   ├── ⚙️ config/
│   │   │   ├── env_config.dart          ← SECRETS go here
│   │   │   └── firebase_options.dart
│   │   ├── 🎨 constants/
│   │   │   ├── app_colors.dart               ← Color palette
│   │   │   ├── app_spacing.dart              ← Size constants
│   │   │   ├── app_typography.dart           ← Font styles
│   │   │   ├── enums.dart                    ← All enums & statuses
│   │   │   ├── layout.dart                   ← Breakpoints
│   │   │   ├── sms_templates.dart            ← 19 SMS templates
│   │   │   └── statement_colors.dart         ← Statement color config
│   │   ├── 🧠 models/
│   │   │   ├── app_update.dart
│   │   │   ├── app_update_status.dart
│   │   │   ├── github_release.dart
│   │   │   ├── statement_org_info.dart
│   │   │   └── system_config.dart
│   │   ├── 🔌 providers/
│   │   │   ├── analytics_engine_provider.dart
│   │   │   ├── analytics_provider.dart
│   │   │   ├── branding_provider.dart
│   │   │   ├── location_providers.dart
│   │   │   ├── org_provider.dart
│   │   │   ├── sms_config_provider.dart
│   │   │   ├── sms_outbox_provider.dart
│   │   │   ├── sms_provider.dart
│   │   │   ├── storage_providers.dart
│   │   │   └── system_config_provider.dart
│   │   ├── 🔧 services/              (30+ services)
│   │   │   ├── analytics_engine.dart         ← Custom analytics engine
│   │   │   ├── analytics_service.dart
│   │   │   ├── app_icon_service.dart         ← Dynamic app icon
│   │   │   ├── app_update_service.dart       ← In-app update checks
│   │   │   ├── auto_update_service.dart      ← Auto-update logic
│   │   │   ├── avatar_upload_service.dart    ← Avatar management
│   │   │   ├── background_handler.dart       ← Background task handler
│   │   │   ├── background_location_service.dart ← Background GPS
│   │   │   ├── email_service.dart            ← Resend email integration
│   │   │   ├── fcm_token_service.dart        ← FCM token management
│   │   │   ├── github_release_service.dart   ← GitHub release checks
│   │   │   ├── haptic_service.dart           ← Haptic feedback
│   │   │   ├── image_compress_service.dart   ← Image compression
│   │   │   ├── live_location_service.dart    ← Real-time GPS streaming
│   │   │   ├── location_cleanup_service.dart ← GPS cleanup
│   │   │   ├── location_service.dart         ← GPS utilities
│   │   │   ├── notification_service.dart     ← Local notifications
│   │   │   ├── notification_navigation_handler.dart ← Deep links
│   │   │   ├── offline_queue_service.dart    ← Queue service
│   │   │   ├── push_notification_service.dart ← FCM push service
│   │   │   ├── push_notification_provider.dart ← Push provider
│   │   │   ├── sms_outbox_service.dart       ← SMS offline queue
│   │   │   ├── sms_scheduler_service.dart    ← WorkManager scheduler
│   │   │   ├── sms_service.dart              ← Native SMS MethodChannel
│   │   │   ├── whatsapp_service.dart         ← WhatsApp messaging
│   │   │   ├── google_drive_service.dart     ← Drive backup/restore
│   │   │   ├── backup_export_service.dart    ← Backup export
│   │   │   ├── restore_backup_service.dart   ← Backup restore
│   │   │   ├── email_settings_service.dart   ← Email config
│   │   │   ├── loan_products_service.dart    ← Loan product management
│   │   │   ├── savings_products_service.dart ← Savings product management
│   │   │   ├── payment_gateway_service.dart  ← Payment gateway service
│   │   │   ├── payment_pdf_service.dart      ← Payment receipt PDF
│   │   │   ├── upi_service.dart              ← UPI payment service
│   │   │   ├── security_policies_service.dart ← Security config
│   │   │   └── location_permission_helper.dart ← GPS permission helper
│   │   ├── 🎨 theme/
│   │   │   ├── app_theme.dart              ← Light/Dark themes
│   │   │   ├── design_system.dart          ← Design tokens
│   │   │   └── theme_provider.dart         ← Theme switching
│   │   ├── 🛠️ utils/                 (14 utilities)
│   │   │   ├── auto_refresh_mixin.dart
│   │   │   ├── calculations.dart
│   │   │   ├── error_formatter.dart
│   │   │   ├── file_download.dart
│   │   │   ├── file_download_stub.dart
│   │   │   ├── file_download_web.dart
│   │   │   ├── formatters.dart
│   │   │   ├── geofence_utils.dart         ← Geofence calculations
│   │   │   ├── json_normalize.dart
│   │   │   ├── kyc_validators.dart
│   │   │   ├── location_permission_helper.dart
│   │   │   ├── polyline_utils.dart
│   │   │   ├── statement_formatters.dart
│   │   │   ├── url_utils.dart
│   │   │   ├── url_utils_stub.dart
│   │   │   └── url_utils_web.dart
│   │   └── 🧩 widgets/               (23+ reusable widgets)
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
│   │       ├── premium_search_overlay.dart
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
│   └── ✨ features/                   (25 feature modules)
│       ├── admin/                    ← Super Admin + Dashboard (5 pages)
│       ├── analytics/                ← Analytics engine + dashboard (3 files)
│       ├── api/                      ← API Key management (3 files)
│       ├── auth/                     ← Login / Signup / Splash / Verify (7 files)
│       ├── billing/                  ← Subscriptions & Invoicing (8 files)
│       ├── branch_manager/           ← Branch Manager Portal (12 pages + widget)
│       ├── branches/                 ← Branch CRUD (4 files)
│       ├── branding/                 ← White-label theming (4 files)
│       ├── chatbot/                  ← 🤖 AI Floating Chatbot (5 files)
│       ├── collections/              ← Collection audit & backdating (1 file)
│       ├── customer_portal/          ← Customer Self-Service (15 pages + 13 widgets)
│       ├── growth/                   ← Growth analytics models (1 file)
│       ├── home/                     ← Executive Admin Dashboard (8 files)
│       ├── invitations/              ← ✉️ Org invitation system (5 files)
│       ├── loans/                    ← 💰 Loan Management (17 files)
│       ├── members/                  ← 👤 Member Onboarding (5 files)
│       ├── operations/               ← Operational utilities (1 file)
│       ├── payments/                 ← 💵 Today's Payments + UPI (11 files)
│       ├── savings/                  ← 🐷 Savings Management (16 files)
│       ├── settings/                 ← ⚙️ Org & App Settings (40+ files)
│       │                              ← Includes: loan products, savings products,
│       │                              ← Google Drive backup/restore, email settings,
│       │                              ← security policies, WhatsApp, app updates,
│       │                              ← activity logs, audit retention, data backup/export,
│       │                              ← help center, legal policies, 2FA, session locks
│       ├── setup/                    ← 🚀 First-run Setup Wizard (2 files)
│       ├── staff/                    ← 📱 Staff Portal (13 pages + 17 widgets)
│       │                              ← Includes: geofence service, background sync,
│       │                              ← conflict resolution, duty auto-resume,
│       │                              ← local database, offline sync engine, security
│       ├── super_admin/              ← 👑 Super Admin Portal (22 pages)
│       ├── transactions/             ← 💳 Transaction History (6 files)
│       │                              ← Includes: PDF, Excel, CSV export services
│       └── users/                    ← 👥 User Management (12 files)
│
├── 🧪 test/                         ← Test files
│   ├── core/providers/
│   ├── core/services/
│   ├── unit/models/
│   ├── unit/utils/
│   └── widget/
│
├── 🔗 integration_test/             ← Integration/E2E tests
│
├── 🗄️ supabase/
│   ├── functions/                    (12 Edge Functions)
│   │   ├── auto-backup/              ← Automated database backup
│   │   ├── chat-proxy/               ← AI chatbot proxy (NVIDIA NIM)
│   │   ├── create-payment-link/      ← Stripe/Razorpay link generation
│   │   ├── google-token-exchange/    ← OAuth token exchange (Drive)
│   │   ├── payment-webhook/          ← Payment gateway webhook
│   │   ├── send-email/               ← Transactional email (Resend)
│   │   ├── send-push-notification/   ← FCM push delivery
│   │   ├── send-whatsapp/            ← WhatsApp Business messaging
│   │   ├── send-welcome-email/       ← Welcome email (Resend)
│   │   ├── set-user-password/        ← Admin password reset + audit
│   │   └── ...
│   ├── migrations/                   (17+ SQL migration files)
│   ├── migrations_staging_only/      (Staging-specific migrations)
│   ├── templates/                    ← SQL templates
│   ├── config.toml                   ← Supabase CLI config
│   ├── supabase_schema.sql           ← Core: members, loans, savings, transactions
│   ├── supabase_staff_schema.sql     ← Staff: wallets, streaks, visits, gamification
│   ├── supabase_update_schema.sql    ← Schema updates
│   ├── fix_all_*.sql                 ← 30+ fix/RLS migration files
│   └── ...
│
├── 📂 sql/
│   └── branch_manager_migration.sql
│
├── 📜 scripts/                      ← Build & deployment scripts
│   ├── bump-version.sh
│   ├── dev.ps1 / dev.sh
│   ├── dev-watch.ps1
│   ├── generate_preset_icons.dart
│   ├── run_tests.bat / run_unit_tests.sh
│   ├── setup-github-secrets.sh
│   ├── setup-staging.ps1
│   ├── strip_bom.ps1
│   └── switch-env.bat / switch-env.sh
│
├── 🛠️ tool/
│   └── release.dart                  ← Release tooling
│
├── 🎬 videos/
│   ├── exec-admin-org-setup/         ← Remotion video (9 scenes)
│   │   └── storyboard_and_direction.md
│   └── microflow-product/            ← Marketing video assets
│       ├── BRIEF.md                  ← Audience & marketing brief
│       ├── BENGALI_SCRIPT.md         ← Bengali marketing script
│       ├── index.html                ← Landing page
│       ├── hyperframes.json          ← Hyperframes config
│       └── ...
│
├── 🔗 n8n/
│   └── chatbot-workflow.json         ← n8n chatbot automation workflow
│
├── 🌐 web_portal/                    ← React marketing site
│   ├── src/App.jsx
│   ├── src/App.css
│   └── ...
│
├── 📂 docs/                          ← Documentation
│   ├── session-log.md                ← Rolling session history
│   ├── DEVELOPMENT_WORKFLOW.md
│   ├── MAPBOX_CUSTOM_STYLE_GUIDE.md
│   ├── compose/plans/
│   └── superpowers/plans/ & specs/
│
├── 🧠 memory/                        ← Durable facts + marketing reference
│   ├── MEMORY.md                     ← Memory index
│   └── *.md                          ← Feature memories
│
├── 📊 graphify-out/                  ← Knowledge graph (AST+semantic)
│   ├── GRAPH_REPORT.md
│   ├── graph.json
│   ├── cache/
│   ├── memory/
│   └── 2026-07-*/                   ← Historical graph snapshots
│
├── 📱 android/, ios/, windows/, linux/  ← Native platform dirs
├── web/                             ← Flutter web build output
├── build/                           ← Build artifacts
├── .github/workflows/               ← CI/CD (GitHub Actions)
└── .dart_tool/, .git/, node_modules/   ← Generated/vendor dirs
```

---

## 🌤️ 11. EDGE FUNCTIONS — Detailed

### Supabase Edge Functions (Deno runtime)

```
Cloud functions running on Deno runtime via Supabase
```

| # | Function | 🔑 Purpose | External API |
|:-:|----------|-----------|-------------|
| 1 | `send-welcome-email` | ✉️ Sends welcome email to new users | Resend API |
| 2 | `chat-proxy` | 🤖 Proxies AI chatbot query | NVIDIA NIM (Llama 3.1 70B) |
| 3 | `set-user-password` | 🔑 Admin endpoint to reset/create passwords + audit log | Supabase Auth |
| 4 | `send-email` | 📧 Transactional email sending | Resend API |
| 5 | `send-push-notification` | 🔔 FCM push notification delivery | Firebase Cloud Messaging |
| 6 | `send-whatsapp` | 💬 WhatsApp Business API messaging | WhatsApp Business API |
| 7 | `auto-backup` | 💾 Automated database backup to cloud | Supabase Storage |
| 8 | `create-payment-link` | 💳 Stripe/Razorpay payment link generation | Stripe/Razorpay |
| 9 | `payment-webhook` | 🔗 Payment gateway webhook handler | Stripe/Razorpay |
| 10 | `google-token-exchange` | 🔑 Google OAuth token exchange (Drive backup) | Google OAuth 2.0 |

---

## ⏱️ 12. SCHEDULED JOBS & DATABASE VIEWS

### Cron Jobs *(run automatically on Supabase)*

| Job | ⏰ Schedule | 🔑 Purpose |
|-----|------------|-----------|
| `mark_overdue_emis` | Daily @ 02:00 | Updates unpaid EMIs past due date → **overdue** |
| `auto-backup` | Scheduled | Automated database backup via Edge Function |
| `sms_scheduler` | WorkManager | Automated EMI reminder dispatch on Android |

### Database Views *(pre-computed queries)*

| View | 🔑 Purpose |
|------|-----------|
| `staff_today_summary` | Today's collection stats per agent (collected, cash, digital, streak, target) |
| `overdue_loans_view` | Overdue loan schedules + member info + GPS + assigned staff |
| `analytics_daily_stats` | Daily analytics aggregated by org, date, event type |

---

## 📊 13. ANALYTICS ENGINE

| Component | 🔑 Purpose |
|-----------|-----------|
| `analytics_engine.dart` | Core analytics computation engine (KPIs, trends, ratios) |
| `analytics_service.dart` | Data service for analytics queries |
| `analytics_models.dart` | Analytics data models |
| `analytics_engine_models.dart` | Engine-specific data models |
| `analytics_page.dart` | Full analytics dashboard page (exec admin) |
| `advanced_analytics_page.dart` | Advanced analytics with drill-downs |
| `analytics_providers.dart` | Riverpod providers for real-time analytics |

**Features:** Real-time KPI dashboards, disbursement vs collection charts, savings growth trends, delinquency tracking, CSV/JSON export, daily/weekly/monthly aggregation, role-scoped data.

---

## 📅 14. DATABASE — Complete Schema

### 💼 Core Business Tables

| Table | 🔑 Purpose | Key Columns |
|-------|-----------|-------------|
| `profiles` | 👤 All users — admin, staff, customer | id, email, role, org_id |
| `members` | 🧾 Customer/member profiles + KYC status | id, org_id, name, pan, aadhar, phone |
| `loans` | 💰 Loan apps — draft → submitted → approved → active → closed | id, org_id, member_id, principal, interest_rate, tenure |
| `loan_schedules` | 📅 EMI schedule per loan | id, loan_id, emi_number, due_date, amount, status |
| `savings` | 🐷 Savings plan with target & maturity | id, org_id, member_id, plan_id, target, maturity |
| `savings_installments` | 💵 Individual savings deposit records | id, savings_id, amount, date, type |
| `transactions` | 💳 ALL financial transactions | id, org_id, type, amount, mode, status |
| `collections` | 📍 Field collections with GPS coordinates | id, staff_id, member_id, amount, lat, lng |
| `branches` | 🏢 Branch office locations | id, org_id, name, location |
| `organizations` | 🏢 Multi-tenant org registry | id, name, slug, status, plan |
| `org_subscriptions` | 💳 Billing & subscription tracking | id, org_id, plan, status |
| `invoices` | 📄 Invoice records | id, org_id, org_subscription_id, amount |
| `subscription_plans` | 📋 Available subscription tiers | id, name, max_members, max_branches, price |
| `org_branding` | 🎨 White-label branding config per org | org_id, primary_color, logo, name |
| `brand_presets` | 🎨 Pre-built branding themes | id, name, colors, fonts |
| `platform_settings` | ⚙️ Global platform configuration | SMTP, SMS, Storage, Security settings |
| `support_tickets` | 🎫 Customer support tickets | id, org_id, subject, status |
| `customer_feedback` | 💬 Feedback submissions | id, org_id, member_id, rating, message |
| `activity_logs` | 📜 Immutable audit trail | id, user_id, action, entity, metadata |
| `api_keys` | 🔑 API key management | org_id, key, permissions |

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
| `sync_queue` | ⏳ Offline operation queue |
| `achievements` | 🏆 Gamification badges |
| `leaderboards` | 🥇 Performance rankings |
| `collection_backdate_audit` | 📜 Collection backdate audit log |

### 🛒 Product Tables (Loan & Savings Products)

| Table | 🔑 Purpose |
|-------|-----------|
| `loan_products` | 💰 Configurable loan products with interest modes, templates |
| `savings_products` | 🐷 Configurable savings products with interest and terms |
| `product_templates` | 📋 Predefined product templates for quick setup |

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

**RLS Highlights:**
- 17+ migration files for RLS policy fixes and schema corrections
- Super-admin role bypass on `org_select` views
- Multi-tenancy isolation via `org_id` on all business tables
- Row-level security enforced at database level (not just app level)

---

## 🔄 15. OFFLINE MODE  *(Works in the middle of nowhere)*

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
| GPS location history | Hive |

### Offline Services

| Service | 🔑 Purpose |
|---------|-----------|
| `offline_queue_service.dart` | Manages operation queue persistence |
| `background_sync_service.dart` | Processes queue when connectivity restored |
| `conflict_resolution_service.dart` | Handles data conflicts during sync |
| `duty_auto_resume_service.dart` | Resumes duty status after app restart |
| `local_database.dart` | Local Hive database helper |
| `offline_sync_engine.dart` | Full offline sync engine |

---

## 🧪 16. TESTING

```
test/
├── core/providers/         ← SMS provider tests
├── core/services/          ← SMS outbox & SMS service tests
├── unit/models/            ← Loan, savings, user model tests
├── unit/utils/             ← Formatter utility tests
└── widget/                 ← Smoke tests

integration_test/
└── E2E flows               ← Full user journey tests
```

### Running Tests

| Command | 🔑 Purpose |
|---------|-----------|
| `flutter test` | 🧪 All unit tests |
| `flutter test test/widget/` | 🧪 Widget smoke tests |
| `flutter test integration_test/` | 🧪 End-to-end tests |
| `flutter analyze` | 🔍 Static analysis |

---

## 📦 17. CI/CD & DEPLOYMENT

### GitHub Actions

| Workflow | 🔑 What it does |
|----------|----------------|
| `analyze` | Runs `flutter analyze` for static analysis |
| `test` | Runs all unit + widget tests |
| `build_web` | Builds Flutter web build |
| `build_android` | Builds Android APK/AAB |
| `release` | Full release pipeline (tag, build, deploy) |

### Scripts

| Script | 🔑 Purpose |
|--------|-----------|
| `scripts/bump-version.sh` | Version bump automation |
| `scripts/dev.sh` / `scripts/dev.ps1` | Development environment setup |
| `scripts/run_tests.bat` / `scripts/run_unit_tests.sh` | Test execution |
| `scripts/switch-env.bat` / `scripts/switch-env.sh` | Environment switching (dev/staging/prod) |
| `scripts/setup-staging.ps1` | Staging environment setup |
| `scripts/setup-github-secrets.sh` | CI secret configuration |
| `tool/release.dart` | Release tooling |

---

## 📱 18. PLATFORMS & BUILD COMMANDS

| Command | 🔑 What it does |
|---------|----------------|
| `flutter run` | 🔧 Development mode |
| `flutter run -d chrome` | 🌐 Web browser |
| `flutter build apk --release` | 🤖 Android APK |
| `flutter build appbundle --release` | 🤖 Android App Bundle |
| `flutter build ios --release` | 🍎 iOS IPA |
| `flutter build web --release` | 🌐 Production web build |
| `flutter build windows --release` | 🪟 Windows desktop |
| `flutter build linux --release` | 🐧 Linux desktop |
| `flutter build macos --release` | 🍎 macOS desktop |

---

## 📊 19. CODE STATISTICS

| Metric | Count |
|--------|-------|
| 📄 Total Dart Files | 449 |
| ✨ Feature Modules | 25 |
| 📱 Pages/Screens | 109+ |
| 🧩 Reusable Widgets | 60+ |
| 🔧 Services | 30+ |
| 🏛️ Repositories | 31+ |
| 🧠 Data Models | 41+ |
| ⚡ Riverpod Providers | 68+ |
| 🗄️ SQL Migration Files | 55+ |
| ☁️ Edge Functions | 12 |
| 📨 SMS Templates | 19 |
| 🧪 Test Files | 13+ |
| 📜 Doc Files | 15+ |

---

## 📱 20. PAGE BREAKDOWN BY PORTAL

```
👑  Super Admin    ██████████████████░░░░░░░░░░  6 pages
🏢  Executive Admin██████████████████████████░░░░░  29 pages
🏗️  Branch Manager ██████████████████░░░░░░░░░░░░░  12 pages
📱  Staff Agent    █████████████████░░░░░░░░░░░░░░  13 pages
👤  Customer       ██████████████████░░░░░░░░░░░░  15 pages
⚙️  Settings/Core  █████████████████░░░░░░░░░░░░░░  ~40 pages
🔐  Auth/Setup     ████████░░░░░░░░░░░░░░░░░░░░░   5 pages
💳  Billing        ██████░░░░░░░░░░░░░░░░░░░░░░░   8 pages
✉️  Invitations    ████░░░░░░░░░░░░░░░░░░░░░░░░░   5 pages
💰  Payments/UPI   ███████░░░░░░░░░░░░░░░░░░░░░░   11 pages
💬  WhatsApp       ██░░░░░░░░░░░░░░░░░░░░░░░░░░░   1 service
🗂️  Google Drive   █████░░░░░░░░░░░░░░░░░░░░░░░░   6 files
📊  Analytics      ███████░░░░░░░░░░░░░░░░░░░░░░   7 files
🔔  Push Notif.    █████░░░░░░░░░░░░░░░░░░░░░░░░   5 files
🛡️  Security       ██████░░░░░░░░░░░░░░░░░░░░░░░   (RLS + 2FA + audit)
─────────────────────────────────────────────────────────
📊  TOTAL         ██████████████████████████████   ~109+ pages
```

---

## 🎨 21. WIDGET SHOWCASE

```
┌─────────────────────────────────────────────────────────────────────┐
│  🧩 23 Reusable Widgets (core/widgets/) + 17+ Staff Widgets        │
├────────────────┬────────────────────────────────────────────────────┤
│ async_value_widget    │ Handles async loading/error/success states   │
│ aurora_background     │ Animated aurora gradient background          │
│ branded_loading       │ Branded loading spinner                      │
│ glass_button          │ Glassmorphic button with gradient border     │
│ glass_card            │ Glassmorphic card container                  │
│ glass_text_field      │ Glassmorphic text input                      │
│ glassmorphic_card     │ Frosted glass card effect                    │
│ hud_navigation        │ HUD-style navigation bar (shared across all │
│                       │ portals — desktop pill + mobile bottom bar) │
│ luma_bar              │ Mobile bottom navigation with glowing states│
│ payment_mode_chips    │ Payment mode selector (cash/UPI/bank/cheque)│
│ powered_by_badge      │ "Powered by" badge                           │
│ premium_app_bar       │ Custom app bar with glass effect             │
│ premium_calendar_sheet│ Calendar bottom sheet                        │
│ premium_search_overlay│ Global search overlay                        │
│ progress_gauge        │ Circular progress with spring animation      │
│ shimmer_card          │ Shimmer loading card                         │
│ shimmer_loading       │ Skeleton loading effect                      │
│ smokey_background     │ Smoky particle background                    │
│ sparkline_chart       │ Mini sparkline chart                         │
│ status_badge          │ Status indicator pill with glow              │
│ update_wrapper        │ App update wrapper                           │
│ ─── Staff Widgets ─── │                                              │
│ on_duty_toggle        │ Staff duty status toggle                     │
│ live_tracking_toggle  │ Live GPS tracking toggle                     │
│ sync_status_bar       │ Offline sync status indicator                │
│ sync_status_card      │ Sync status card                             │
│ wallet_card           │ Agent cash-in-hand display                   │
│ check_in_card         │ GPS visit check-in card                      │
│ duty_status_card      │ Current duty status display                  │
│ target_progress_ring  │ Circular target progress indicator           │
│ leaderboard_snapshot  │ Staff ranking snapshot                       │
│ weekly_performance_chart│ Weekly collection bar chart               │
│ activity_feed_timeline│ Staff activity timeline                      │
│ notification_bell     │ Notification indicator                       │
│ gps_status_chip       │ GPS status chip                              │
│ receipt_generator     │ Payment receipt generate widget              │
│ break_card            │ Work break logging card                      │
│ today_agenda_list     │ Today's collection agenda                    │
│ location_history_sheet│ GPS location history bottom sheet            │
└────────────────┴────────────────────────────────────────────────────┘
```

---

## 🔑 22. ENUMS & STATUS TYPES

```
👤  UserRole        → superAdmin | executiveAdmin | manager | collectionAgent | customer
💰  LoanStatus      → draft | pending | underReview | approved | active | closed | rejected | restructured
📅  EMIStatus       → pending | paid | overdue | waived | pendingPayment
🏦  InterestType    → flat | reducingBalance
📐  InterestMode    → percentage | amount
🐷  SavingsStatus   → active | paused | matured | withdrawn | cancelled | closed
📆  SavingsFreq     → daily | weekly | monthly
💳  TransactionType → loanDisbursement | emiPayment | savingsDeposit | savingsWithdrawal | penalty | staffCashDeposit | other
💵  PaymentMode     → cash | upi | bankTransfer | cheque | card
👥  CustomerStatus  → active | inactive | blacklisted
🗓️  CollectionFreq  → daily | weekly | monthly | yearly
🪪  KYCStatus       → pending | verified | rejected
⏳  TenureUnit      → days | weeks | months | years
🏢  BranchStatus    → active | inactive | suspended
📱  SyncStatus      → pending | syncing | synced | failed | dead
🏆  AchievementType → streak | collection | target | milestone
💬  TicketStatus    → open | in_progress | resolved | closed
```

---

## ⚡ 23. SUPER POWER FEATURES

```
┌───────────────────────────────────────────────────────────────────┐
│  ⚡ POWER FEATURES — Things that make this app special           │
├──────────────────────────┬────────────────────────────────────────┤
│ 🤖 AI Chatbot           │ Floating, draggable, position saves    │
│                          │ NVIDIA NIM Llama 3.1 70B              │
│ 🗺️ Live GPS Maps        │ Staff & customer location tracking     │
│                          │ Mapbox + Flutter Map + Geofence       │
│ 📍 Visit Check-in/out   │ GPS-tagged field visits                │
│ 🔥 Collection Streaks   │ Gamified daily collection goals        │
│ 🏆 Achievements          │ Badges for milestones                  │
│ 🥇 Leaderboards          │ Staff performance rankings             │
│ 📵 Offline Mode          │ Full field ops without internet        │
│ 🔄 Auto-Sync             │ Background sync when online            │
│ 📬 19 SMS Templates      │ TRAI/DLT compliant auto-reminders      │
│ 📱 Push Notifications    │ FCM real-time alerts                   │
│ 💬 WhatsApp              │ Automated customer messaging           │
│ 📧 Email (Resend)        │ Transactional emails (welcome, alerts) │
│ 💳 Payment Links         │ Stripe/Razorpay ready                  │
│ 💰 UPI Payments          │ Instant digital payments               │
│ 🧾 Receipt Sharing       │ Share payment receipts instantly       │
│ 📄 Statement Generation  │ PDF, Excel, CSV + archival             │
│ 🗂️ Google Drive Backup   │ Cloud export & restore                 │
│ 🔐 Biometric Login       │ Fingerprint / Face ID unlock           │
│ 🔐 2FA (TOTP)            │ Admin two-factor authentication        │
│ 🎨 White-label Branding  │ Custom org colors, logos, icons        │
│ 🎯 Daily Targets         │ Daily/weekly/monthly collection goals  │
│ 💵 Wallet Tracking        │ Cash-in-hand per agent                 │
│ 🏦 Multi-tenancy         │ Isolated orgs (10,000+ members)        │
│ 📊 Real-time Analytics   │ Live dashboards & reports              │
│ ⚡ Smart Overdue Detect  │ Auto-mark overdue EMIs daily           │
│ ✉️ Invitation System      │ Email org onboarding                   │
│ 📹 Video Tutorials       │ Remotion-based org setup tutorial      │
│ 🔗 N8n Automation        │ Chatbot workflow automation            │
│ 🌐 Web Portal            │ React marketing site + landing page    │
└──────────────────────────┴────────────────────────────────────────┘
```

---

## ⚠️ 24. PRE-LAUNCH CHECKLIST

```
Before going live, verify these things ✅:

[ ] 📵 Test offline collection: record → wait → go online → sync works?
[ ] 📍 Verify GPS permissions work on Android AND iOS
[ ] 🔄 Test sync with 50+ pending operations at once
[ ] 🛡️ Confirm RLS policies in Supabase are enabled on all tables
[ ] 📤 Test receipt sharing (Share Plus)
[ ] 📱 Test push notifications (FCM) on both Android & iOS
[ ] 🔗 Test payment link creation and webhook handling
[ ] 📱 Test WhatsApp messaging integration
[ ] 💾 Test Google Drive backup export and restore
[ ] 🧪 Run flutter test — all green?
[ ] 📱 Test on real Android & iOS device (not just simulator)
[ ] 🔍 Check no hardcoded API keys in lib/ directory
[ ] 📋 Verify .env is in .gitignore (secrets protected)
[ ] 🗄️ Run all 50+ SQL migration files in Supabase
[ ] 📱 Test biometric auth vs fallback password
[ ] 📨 Test SMS delivery on both Android & iOS
[ ] 🌐 Test web portal build and deployment
[ ] 🎬 Verify Remotion video renders correctly
[ ] 🤖 Test N8n chatbot workflow
[ ] 📊 Verify analytics engine calculations
[ ] 🔑 Test TOTP 2FA for admin accounts
```

---

## 🤝 25. Contributing

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
- Staging first, always — never run SQL on production without explicit go-ahead

---

## 📊 26. At a Glance

```
   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
   │  Flutter │────▶│  Supabase│────▶│  Riverpod│────▶│ GoRouter │
   │  UI 📱   │     │  Cloud ☁│     │  State ⚡│     │  Routes 🗺│
   └──────────┘     └──────────┘     └──────────┘     └──────────┘
        │                                    │
        ▼                                    ▼
   ┌──────────┐                     ┌──────────┐
   │  Hive 💾 │                     │  Edge ☁  │
   │ Offline  │                     │ Functions│
   └──────────┘                     └──────────┘
        │                                    │
        ▼                                    ▼
   ┌──────────┐                     ┌──────────┐
   │  FCM 🔔   │                     │  Firebase│
   │  Push Not│                     │  Auth    │
   └──────────┘                     └──────────┘
```

**MicroFlow Pro** — Built with ❤️ for MFI Field Collectors

*© 2024–2026 MicroFlow Pro | MIT License*

[![GitHub](https://img.shields.io/badge/GitHub-sansayan01/finance_app_zo-181717?style=for-the-badge&logo=github)](https://github.com/sansayan01/finance_app_zo)

</div>