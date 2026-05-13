<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?style=for-the-badge&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Supabase-2.0+-3ECF8E?style=for-the-badge&logo=supabase" alt="Supabase">
  <img src="https://img.shields.io/badge/Dart-3.4+-0175C2?style=for-the-badge&logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
</div>

<h1 align="center">MicroFlow Pro - Micro-Finance</h1>
<p align="center"><strong>Premium Micro-Finance Management Ecosystem</strong></p>
<p align="center">Complete Admin Portal + Field Staff Collector App</p>

---

## 📖 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Admin Portal](#admin-portal)
- [Staff Portal](#staff-portal)
- [Database Schema](#database-schema)
- [API Reference](#api-reference)
- [Security](#security)
- [Performance](#performance)
- [Offline Support](#offline-support)
- [Screenshots](#screenshots)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

MicroFlow Pro is a **cross-platform financial management application** designed for Micro-Finance Institutions (MFIs) and savings groups. It provides a complete ecosystem for managing loans, savings, members, and field operations.

### Key Capabilities

| Portal | Users | Primary Functions |
|--------|-------|-------------------|
| **Admin Portal** | Branch managers, Admins | Loan management, member onboarding, staff management, analytics, reports |
| **Staff Portal** | Field collectors | Daily collections, customer visits, cash management, offline operations |

---

## ✨ Features

### 🏢 Admin Portal

#### Dashboard
- **Real-time Statistics** - Total loans, active members, collections, disbursements
- **Trend Analysis** - Sparkline charts showing 7-day collection trends
- **Quick Actions** - One-tap access to common operations
- **Pending Alerts** - Overdue EMIs, pending applications
- **Search** - Global search for members, loans, transactions
- **Notifications** - Real-time alerts for important events

#### Loan Management
- **Loan Creation** - Full loan application workflow
- **EMI Scheduling** - Auto-generate EMI schedules (flat/reducing interest)
- **Status Tracking** - Pending → Approved → Active → Closed
- **Bulk Operations** - Batch approvals, status updates

#### Savings Management
- **Recurring Savings Plans** - Daily, weekly, monthly schemes
- **Deposit Tracking** - Record and track deposits
- **Interest Calculation** - Automatic maturity calculations

#### Member Management
- **Member Onboarding** - Complete KYC workflow
- **Profile Management** - Personal details, documents, addresses
- **Loan History** - Complete loan history per member
- **Savings History** - Deposit patterns and maturity tracking

#### User & Staff Management
- **Role-based Access** - Admin, Manager, Field Staff
- **Staff Profiles** - Branch assignment, targets, performance
- **Activity Logs** - Complete audit trail of all actions

#### Analytics
- **Collection Analytics** - Daily, weekly, monthly trends
- **Performance Metrics** - Staff efficiency, branch performance
- **Financial Reports** - Disbursement vs collection ratios

#### Smart Assistant
- **Floating Chatbot** - AI-powered assistance
- **Quick Queries** - Ask about loans, members, collections
- **Voice Input** - Hands-free operation
- **Contextual Help** - Screen-specific guidance

### 👨‍💼 Staff Portal (Field Collector)

#### Home Dashboard
- **Today's Agenda** - EMIs due, visits scheduled, targets
- **Wallet Balance** - Cash-in-hand tracking
- **Collection Streak** - Gamification element for motivation
- **Target Progress** - Daily/weekly/monthly goals
- **GPS Status** - Real-time location tracking indicator
- **Sync Status** - Offline/online status with pending count

#### Collection Operations
- **Record Collection** - Cash, UPI, bank transfer, cheque, card
- **GPS Capture** - Automatic location stamp per collection
- **Receipt Generation** - Text/PDF receipts for customers
- **Payment Mode Selection** - Multiple payment methods
- **Partial Collections** - Record partial EMI payments
- **Overdue Management** - Prioritized overdue list with severity

#### Customer Management
- **Customer Search** - Quick search by name, phone, loan number
- **Customer Profile** - Complete loan/savings history
- **Loan Details** - Outstanding balance, EMI schedule
- **Visit History** - Previous visits and collections

#### Field Operations
- **Visit Check-in/out** - GPS-tagged visit tracking
- **Break Logging** - Work time tracking with breaks
- **Daily Summary** - End-of-day collection report
- **Cash Deposit** - Submit cash to branch/office
- **Activity Tracking** - Work hours, distance covered

#### Offline Support
- **Local Database** - SQLite/Hive for offline data
- **Operation Queue** - Pending operations synced later
- **Conflict Resolution** - Last-write-wins with audit trail
- **Auto-sync** - Background sync when online
- **Sync Status Badge** - Visual indicator of sync state

#### Gamification
- **Collection Streaks** - Daily collection streaks
- **Achievements** - Badges for milestones
- **Leaderboards** - Compare with other collectors
- **Targets** - Daily/weekly/monthly goals

---

## 🛠️ Tech Stack

### Frontend
| Technology | Purpose |
|------------|---------|
| **Flutter 3.11+** | Cross-platform UI framework |
| **Riverpod 2.4+** | State management |
| **GoRouter 14+** | Declarative routing |
| **Flutter Animate** | Smooth animations |
| **FL Chart** | Beautiful charts |
| **Google Fonts** | Typography |
| **Shimmer** | Loading placeholders |

### Backend
| Technology | Purpose |
|------------|---------|
| **Supabase** | PostgreSQL database, Auth, Realtime |
| **Row Level Security** | Data isolation per role |
| **PostgreSQL Functions** | Server-side logic |

### Local Storage
| Technology | Purpose |
|------------|---------|
| **Hive** | Local database for offline |
| **SharedPreferences** | Settings, tokens |
| **SQLite** | Offline data caching |

### Integrations
| Technology | Purpose |
|------------|---------|
| **Geolocator** | GPS location tracking |
| **Local Auth** | Biometric authentication |
| **Internet Connection Checker** | Connectivity monitoring |
| **Share Plus** | Receipt sharing |
| **Path Provider** | File storage paths |

---

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # MaterialApp configuration
│
├── core/
│   ├── constants/
│   │   ├── app_colors.dart   # Color palette
│   │   ├── app_strings.dart  # String constants
│   │   └── enums.dart        # App-wide enums
│   ├── theme/
│   │   ├── app_theme.dart    # Light/Dark themes
│   │   └── theme_provider.dart
│   ├── providers/
│   │   └── storage_providers.dart
│   └── widgets/
│       └── hud_navigation.dart
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── models/user_model.dart
│   │   │   └── repositories/auth_repository.dart
│   │   └── presentation/
│   │       ├── pages/login_page.dart
│   │       ├── pages/signup_page.dart
│   │       └── providers/auth_provider.dart
│   │
│   ├── home/
│   │   ├── data/
│   │   │   └── providers/dashboard_providers.dart
│   │   └── presentation/
│   │       ├── pages/home_page.dart          # Admin dashboard
│   │       └── pages/staff_home_page.dart    # Old staff page (legacy)
│   │
│   ├── staff/                                 # NEW STAFF PORTAL
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── staff_profile_model.dart
│   │   │   │   ├── collection_model.dart
│   │   │   │   ├── wallet_model.dart
│   │   │   │   ├── streak_model.dart
│   │   │   │   ├── target_model.dart
│   │   │   │   ├── activity_log_model.dart
│   │   │   │   ├── staff_location_model.dart
│   │   │   │   ├── achievement_model.dart
│   │   │   │   ├── leaderboard_model.dart
│   │   │   │   └── audit_log_model.dart
│   │   │   ├── repositories/
│   │   │   │   ├── staff_repository.dart
│   │   │   │   └── collection_repository.dart
│   │   │   ├── services/
│   │   │   │   ├── offline_sync_engine.dart
│   │   │   │   ├── local_database_service.dart
│   │   │   │   ├── background_sync_service.dart
│   │   │   │   ├── conflict_resolution_service.dart
│   │   │   │   └── security_service.dart
│   │   │   └── providers/
│   │   │       ├── staff_providers.dart
│   │   │       ├── collection_providers.dart
│   │   │       ├── sync_providers.dart
│   │   │       └── gamification_providers.dart
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── staff_home_dashboard.dart
│   │       │   ├── collection_form_page.dart
│   │       │   ├── collection_list_page.dart
│   │       │   ├── customer_search_page.dart
│   │       │   ├── customer_detail_page.dart
│   │       │   ├── collection_history_page.dart
│   │       │   ├── overdue_list_page.dart
│   │       │   ├── visit_checkin_page.dart
│   │       │   ├── daily_summary_page.dart
│   │       │   ├── cash_deposit_page.dart
│   │       │   ├── break_logging_page.dart
│   │       │   ├── pending_operations_page.dart
│   │       │   ├── gamification_dashboard.dart
│   │       │   └── analytics_dashboard.dart
│   │       └── widgets/
│   │           ├── wallet_card.dart
│   │           ├── target_progress_ring.dart
│   │           ├── sync_status_bar.dart
│   │           ├── gps_status_chip.dart
│   │           ├── today_agenda_list.dart
│   │           ├── collection_card.dart
│   │           ├── collection_filter_widgets.dart
│   │           └── offline_mode_indicator.dart
│   │
│   ├── loans/
│   │   ├── data/
│   │   │   ├── models/loan_model.dart
│   │   │   ├── models/emi_schedule_model.dart
│   │   │   └── repositories/loans_repository.dart
│   │   └── presentation/
│   │       ├── pages/loans_page.dart
│   │       ├── pages/loan_detail_page.dart
│   │       ├── pages/new_loan_page.dart
│   │       └── widgets/collection_sheet.dart
│   │
│   ├── savings/
│   │   ├── data/
│   │   │   ├── models/savings_model.dart
│   │   │   └── repositories/savings_repository.dart
│   │   └── presentation/
│   │       ├── pages/savings_page.dart
│   │       ├── pages/saving_detail_page.dart
│   │       └── pages/new_recurring_saving_page.dart
│   │
│   ├── members/
│   │   ├── data/
│   │   │   ├── models/member_model.dart
│   │   │   └── repositories/members_repository.dart
│   │   └── presentation/
│   │       └── pages/member_onboarding_page.dart
│   │
│   ├── users/
│   │   ├── data/
│   │   │   ├── models/user_model.dart
│   │   │   └── repositories/user_repository.dart
│   │   └── presentation/
│   │       ├── pages/users_page.dart
│   │       ├── pages/new_user_page.dart
│   │       └── pages/user_details_page.dart
│   │
│   ├── transactions/
│   │   ├── data/
│   │   │   ├── models/transaction_model.dart
│   │   │   └── repositories/transactions_repository.dart
│   │   └── presentation/
│   │       └── pages/transactions_page.dart
│   │
│   ├── analytics/
│   │   └── presentation/
│   │       └── pages/analytics_page.dart
│   │
│   ├── settings/
│   │   ├── data/
│   │   │   ├── repositories/settings_repository.dart
│   │   │   └── providers/brand_provider.dart
│   │   └── presentation/
│   │       ├── pages/settings_page.dart
│   │       ├── pages/profile_page.dart
│   │       └── pages/activity_logs_page.dart
│   │
│   └── chatbot/
│       ├── data/
│       │   └── models/chat_message.dart
│       └── presentation/
│           └── widgets/floating_chatbot.dart
│
├── providers/
│   └── supabase_provider.dart
│
└── router/
    └── app_router.dart

supabase/
├── schema.sql                 # Core tables
├── staff_schema.sql           # Staff portal tables
├── functions/                 # PostgreSQL functions
│   └── generate_emi_schedule.sql
└── rls_policies.sql           # Row Level Security
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.11 or higher
- Dart SDK 3.4 or higher
- Supabase account (free tier works)
- Android Studio / VS Code

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

3. **Configure environment**
Create a `.env` file in the project root:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

Or use `--dart-define` flags:
```bash
flutter run --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=...
```

4. **Set up Supabase**
   - Create a new Supabase project
   - Run `supabase_schema.sql` in SQL Editor
   - Run `supabase_staff_schema.sql` in SQL Editor
   - Enable Row Level Security (already in schema)

5. **Run the app**
```bash
flutter run
```

---

## 🏢 Admin Portal

### Dashboard Features

| Widget | Description |
|--------|-------------|
| **Stats Cards** | Total loans, members, collections, disbursements |
| **Collection Trend** | 7-day sparkline |
| **Quick Actions** | New loan, new member, collect EMI |
| **Recent Activity** | Latest transactions |
| **Pending Items** | Overdue EMIs, pending applications |

### Navigation

| Tab | Description |
|-----|-------------|
| **Home** | Dashboard overview |
| **Loans** | Loan management, EMI collection |
| **Savings** | Savings plans, deposits |
| **Users** | Staff management |
| **Settings** | Profile, activity logs |

### Role-Based Access

| Role | Permissions |
|------|-------------|
| **Admin** | Full access to all features |
| **Manager** | Branch-level operations, staff oversight |
| **Field Staff** | Collection operations only |

---

## 👨‍💼 Staff Portal

### Home Dashboard

```
┌─────────────────────────────────────┐
│  👋 Good Morning, Collector!        │
│  📍 GPS: Active  📶 Online  🔄 0    │
├─────────────────────────────────────┤
│  💰 Wallet: ₹12,500                 │
│  🔥 Streak: 5 days                  │
│  🎯 Today: ₹15,000 / ₹20,000       │
├─────────────────────────────────────┤
│  📋 Today's Agenda                  │
│  ├─ EMI Due: 12 customers           │
│  ├─ Overdue: 3 customers            │
│  └─ Visits: 5 scheduled             │
├─────────────────────────────────────┤
│  ⚡ Quick Actions                   │
│  [Record] [Search] [History]        │
└─────────────────────────────────────┘
```

### Collection Flow

1. **Select Customer** → Search or tap from list
2. **View Details** → Outstanding, EMI schedule
3. **Record Collection** → Enter amount, payment mode
4. **GPS Capture** → Automatic location stamp
5. **Generate Receipt** → Share with customer
6. **Sync** → Online: immediate, Offline: queued

### Offline Operation

```
┌─────────────────────────────────────┐
│  📴 OFFLINE MODE                     │
│  3 pending operations                │
│  [View Pending] [Force Sync]         │
└─────────────────────────────────────┘
```

---

## 🗄️ Database Schema

### Core Tables

| Table | Purpose |
|-------|---------|
| `members` | Customer profiles |
| `loans` | Loan applications |
| `emi_schedule` | EMI repayment schedule |
| `savings_plans` | Recurring savings |
| `savings_deposits` | Deposit records |
| `transactions` | All financial transactions |
| `profiles` | User profiles (admin/staff) |

### Staff Portal Tables

| Table | Purpose |
|-------|---------|
| `branches` | Branch offices |
| `staff_profiles` | Staff details, branch assignment |
| `staff_wallets` | Cash-in-hand tracking |
| `staff_locations` | GPS location history |
| `staff_streaks` | Collection streaks |
| `staff_breaks` | Work time breaks |
| `visits` | Customer visits |
| `collections` | Field collections |
| `cash_deposits` | Branch deposits |
| `collection_targets` | Daily/weekly targets |
| `activity_logs` | Complete audit trail |
| `sync_queue` | Offline operation queue |
| `achievements` | Gamification badges |
| `leaderboards` | Performance rankings |

### Row Level Security

All tables have RLS enabled with these policies:
- Staff can only access their own data
- Managers can access branch-level data
- Admins have full access
- Collections are filtered by staff_id

---

## 🔒 Security

### Authentication
- Supabase Auth with email/password
- Biometric authentication (fingerprint/face)
- Session management with refresh tokens

### Authorization
- Role-based access control (RBAC)
- Row Level Security (RLS) in database
- Route guards in app router

### Data Protection
- No images/audio stored (metadata only)
- GPS data encrypted at rest
- API keys stored in environment variables
- No hardcoded credentials in code

### Audit Trail
- All actions logged in `activity_logs`
- Timestamp, user, action, entity, metadata
- Immutable records (no deletion, only archival)

---

## ⚡ Performance

### Optimization Strategies

| Strategy | Implementation |
|----------|----------------|
| **SQL Aggregation** | Replace Dart-side calculations |
| **Pagination** | Limit queries to 50 items |
| **Lazy Loading** | Load data on-demand |
| **Caching** | Local database for frequent queries |
| **Indexing** | Database indexes on foreign keys |
| **Debouncing** | Search input debounced |

### Query Optimization

```sql
-- Before: Fetch all, calculate in Dart
SELECT * FROM loans;  -- Then calculate in app

-- After: Aggregate in SQL
SELECT 
  COUNT(*) as total_loans,
  SUM(outstanding_balance) as total_outstanding
FROM loans WHERE status = 'active';
```

---

## 📴 Offline Support

### Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   UI Layer   │────▶│  Sync Engine │────▶│   Supabase   │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │  Local DB    │
                     │  (Hive)      │
                     └──────────────┘
```

### Sync Flow

1. **Online**: Operations go directly to Supabase
2. **Offline**: Operations queued in local database
3. **Reconnect**: Background sync processes queue
4. **Conflict**: Last-write-wins with audit log

### Data Cached Offline
- Staff profile
- Today's EMIs
- Customer list (recent 50)
- Loan details (viewed in last 24h)
- Wallet balance
- Current targets

---

## 📸 Screenshots

### Admin Portal

| Dashboard | Loans | Analytics |
|-----------|-------|-----------|
| *Coming soon* | *Coming soon* | *Coming soon* |

### Staff Portal

| Home | Collection | Customer |
|------|------------|----------|
| *Coming soon* | *Coming soon* | *Coming soon* |

---

## 📊 Code Statistics

### Files Count

| Category | Count |
|----------|-------|
| **Admin Portal Files** | 59 |
| **Staff Portal Files** | 46 |
| **Total Dart Files** | ~105 |

### Pages Count

| Portal | Pages |
|--------|-------|
| **Admin Portal** | 20 pages |
| **Staff Portal** | 14 pages |
| **Total** | 34 pages |

### Admin Portal Pages

| Page | Purpose |
|------|---------|
| `home_page.dart` | Dashboard |
| `login_page.dart` | Authentication |
| `signup_page.dart` | Registration |
| `loans_page.dart` | Loan list |
| `loan_detail_page.dart` | Loan details |
| `new_loan_page.dart` | Create loan |
| `savings_page.dart` | Savings list |
| `saving_detail_page.dart` | Savings details |
| `new_recurring_saving_page.dart` | Create savings |
| `users_page.dart` | Staff list |
| `user_details_page.dart` | Staff details |
| `new_user_page.dart` | Create staff |
| `member_onboarding_page.dart` | Onboard member |
| `transactions_page.dart` | Transaction history |
| `analytics_page.dart` | Analytics dashboard |
| `settings_page.dart` | Settings |
| `profile_page.dart` | User profile |
| `activity_logs_page.dart` | Audit logs |
| `notifications_page.dart` | Notifications |
| `search_page.dart` | Global search |

### Staff Portal Pages

| Page | Purpose |
|------|---------|
| `staff_home_dashboard.dart` | Staff home |
| `collection_list_page.dart` | Today's EMIs |
| `collection_form_page.dart` | Record collection |
| `customer_search_page.dart` | Find customers |
| `customer_detail_page.dart` | Customer info |
| `collection_history_page.dart` | Past collections |
| `overdue_list_page.dart` | Overdue EMIs |
| `visit_checkin_page.dart` | Visit tracking |
| `daily_summary_page.dart` | Day summary |
| `cash_deposit_page.dart` | Submit cash |
| `break_logging_page.dart` | Work breaks |
| `pending_operations_page.dart` | Offline queue |
| `gamification_dashboard.dart` | Achievements |
| `analytics_dashboard.dart` | Performance |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `flutter analyze` before committing
- Write tests for new features

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Sayan** - [@sansayan01](https://github.com/sansayan01)

---

<div align="center">
  <p>Built with ❤️ for MFI Field Collectors</p>
  <p>© 2024-2026 MicroFlow Pro</p>
</div>
