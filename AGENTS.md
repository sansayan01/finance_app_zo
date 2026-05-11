# MicroFlow Pro - Staff Portal

## Project Overview

MicroFlow Pro is a **Flutter cross-platform financial management app** for MFIs (Micro-Finance Institutions) and savings groups. 

**Repository**: https://github.com/sansayan01/finance_app_zo

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
- Role-based redirect (staff → /staff, admin → /)
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

4. **Run app**
```bash
flutter pub get
flutter run
```

---

## 🔑 Key Features

### Staff Portal
- **Dashboard**: Wallet, streak, targets, today's agenda
- **Collections**: Record with GPS, multiple payment modes
- **Offline**: Queue collections, auto-sync when online
- **Customers**: Search, view details, loan history
- **Visits**: GPS-tagged check-in/out
- **Gamification**: Streaks, achievements, leaderboards

### Admin Portal
- **Dashboard**: Stats, trends, quick actions
- **Loans**: Create, approve, track, close
- **Savings**: Plans, deposits, maturity
- **Users**: Staff management, role assignment
- **Analytics**: Reports, performance metrics

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
- Staff can only read/update their own data
- Admins have full access
- Collections are filtered by staff_id
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

**Last Updated**: May 12, 2026