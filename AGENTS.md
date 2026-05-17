# MicroFlow Pro

## Project Overview

MicroFlow Pro is a **Flutter cross-platform financial management app** for MFIs (Micro-Finance Institutions) and savings groups. 

**Repository**: https://github.com/sansayan01/finance_app_zo

---

## 👥 Role Hierarchy

| Level | Role | Scope | Description |
|-------|------|-------|-------------|
| 1 | **Super Admin** | Platform | Manages all organizations, platform-wide settings |
| 2 | **Executive Admin** | Organization | Organization-level management, oversees all branches |
| 3 | **Branch Manager** | Branch | Branch-level oversight, manages staff within a branch |
| 4 | **Staff / Collection Agent** | Field | Field operations — collections, visits, GPS check-ins |
| 5 | **Customer** | Self | End user — loan recipient, savings member |

---

## ✅ Implementation Status

| Phase | Name | Status | Description |
|-------|------|--------|-------------|
| **1** | Core Foundation | ✅ COMPLETE | Database schema, models, repositories |
| **2** | Essential Screens | ✅ COMPLETE | Collection list, form, customer pages |
| **3** | Field Operations | ✅ COMPLETE | Overdue, visit check-in, daily summary |
| **4** | Offline Engine | ✅ COMPLETE | Sync engine, local queue, conflict resolution |
| **5** | Gamification | ✅ COMPLETE | Streaks, achievements, leaderboards |
| **6** | Admin Integration | ✅ COMPLETE | Audit logs, analytics, security |
| **7** | Router Integration | ✅ FIXED | All staff routes connected |
| **8** | Offline Sync | ✅ FIXED | Integrated into collection flow |
| **9** | Security | ✅ FIXED | Environment variables, no hardcoded secrets |
| **10** | Performance | ✅ FIXED | SQL aggregation, efficient queries |
| **11** | Polish | ✅ COMPLETE | GPS accuracy, receipt generation |

---

## 🔧 Recent Fixes (Critical Issues Resolved)

### 1. Router Integration ✅
- All staff pages now properly connected to router
- StaffShell with dedicated bottom navigation
- Role-based redirect (super_admin → /super-admin, executive_admin → /, branch_manager → /branch, staff → /staff, customer → /customer)
- Pending count badge on sync tab

### 2. Offline Sync Integration ✅
- CollectionNotifier checks connectivity before recording
- Offline collections queued in SharedPreferences
- Auto-sync when online
- Sync status badge updates in real-time

### 3. Security ✅
- Supabase credentials moved to environment variables
- .env.example provided for setup
- EnvConfig class for --dart-define support
- .gitignore excludes .env files

### 4. Performance ✅
- getLoanSummary() optimized - no more 1000 record fetch
- Direct aggregation on response data
- Reduced data transfer

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── config/
│   │   └── env_config.dart          # Environment configuration
│   ├── providers/
│   │   └── storage_providers.dart   # SharedPreferences provider
│   └── constants/
│       ├── app_colors.dart
│       └── enums.dart
│
├── features/
│   ├── staff/                       # Staff Portal
│   │   ├── data/
│   │   │   ├── models/
│   │   │   ├── repositories/
│   │   │   ├── services/
│   │   │   └── providers/
│   │   └── presentation/
│   │       ├── pages/               # 14 pages
│   │       └── widgets/             # 12 widgets
│   │
│   ├── home/                        # Admin Dashboard
│   ├── loans/                       # Loan Management
│   ├── savings/                     # Savings Management
│   └── ...                          # Other features
│
└── router/
    └── app_router.dart              # GoRouter with staff routes
```

---

## 🚀 Quick Start

1. **Clone repo**
```bash
git clone https://github.com/sansayan01/finance_app_zo.git
cd finance_app_zo
```

2. **Configure environment**
```bash
cp .env.example .env
# Edit .env with your Supabase credentials
```

3. **Run Supabase SQL**
   - Run `supabase_schema.sql` in Supabase SQL Editor
   - Run `supabase_staff_schema.sql` in Supabase SQL Editor
   - Run `fix_staff_multi_tenancy.sql` in Supabase SQL Editor (Critical for multi-tenancy)
   - Run `fix_rls_final.sql` in Supabase SQL Editor (Critical for Wizard RLS)

4. **Run app**
```bash
flutter pub get
flutter run
```

---

## 🔑 Key Features

### Super Admin Portal
- **Organizations**: Create, manage, suspend organizations
- **Platform Settings**: Global configuration, billing, limits

### Executive Admin Portal (Organization)
- **Dashboard**: Total outstanding, active members, today's collection, PAR rate
- **Quick Actions**: New Loan, Savings, Add User, Timeline, Branches
- **Loans**: Create, approve, track, close
- **Savings**: Plans, deposits, maturity
- **Users**: Staff & branch manager management, role assignment
- **Analytics**: Reports, performance metrics
- **Today's Agenda**: Due today overview

### Branch Manager Portal
- **Branch Dashboard**: Branch-level stats, staff performance
- **Staff Management**: Assign areas, monitor collections
- **Approvals**: Branch-level loan/savings approvals

### Staff / Collection Agent Portal
- **Dashboard**: Wallet, streak, targets, today's agenda
- **Collections**: Record with GPS, multiple payment modes
- **Offline**: Queue collections, auto-sync when online
- **Customers**: Search, view details, loan history
- **Visits**: GPS-tagged check-in/out
- **Gamification**: Streaks, achievements, leaderboards

### Customer Portal
- **Loan Status**: View active loans, repayment schedule
- **Payment History**: Track payments made
- **Savings**: View savings balance, maturity

---

## ⚠️ Known Issues to Verify

Before production:
- [ ] Test offline collection flow end-to-end
- [ ] Verify GPS permissions on Android/iOS
- [ ] Test sync with multiple pending operations
- [ ] Verify RLS policies in Supabase
- [ ] Test receipt sharing

---

## 📝 Database Notes

All tables have Row Level Security enabled:
- **Super Admin**: Full platform access across all organizations
- **Executive Admin**: Full access within their organization
- **Branch Manager**: Access scoped to their branch
- **Staff**: Can only read/update their own data, collections filtered by staff_id
- **Customer**: Can only view their own loans, payments, and savings
- Sync status is tracked per record
- Streaks are calculated automatically
- Wallet updates happen via database triggers
- **No images/audio stored - metadata only**

---

## 🔄 Git Setup

The repository is configured for easy push/pull:
```bash
git pull   # Pull latest changes
git push   # Push your changes
```

Credentials are stored securely.

---

## 📊 Code Statistics

- **Staff Portal Files**: ~40 files
- **Total Lines**: ~15,000 lines
- **Pages**: 14
- **Widgets**: 12
- **Providers**: 25+
- **Models**: 10

---

**Last Updated**: May 18, 2026