# MicroFlow Pro - Staff Portal

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?style=for-the-badge&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.1+-0175C2?style=for-the-badge&logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase" alt="Supabase">
  <img src="https://img.shields.io/badge/Riverpod-State-7B68EE?style=for-the-badge" alt="Riverpod">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
</div>

<div align="center">
  <h3>🌍 Cross-Platform MFI Field Collection App</h3>
  <p>Built for Micro-Finance Institutions & Savings Groups</p>
</div>

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Screenshots](#-screenshots)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Database Schema](#-database-schema)
- [Getting Started](#-getting-started)
- [Implementation Status](#-implementation-status)
- [API Reference](#-api-reference)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

**MicroFlow Pro Staff Portal** is a production-ready Flutter application designed for **MFI field collectors** who work in challenging conditions:

- 🌤️ **Hot weather & bright sunlight** — High contrast UI
- 📶 **Poor network** — Offline-first architecture
- 🔋 **Low battery** — Optimized performance
- ⚡ **High transaction volume** — One-tap actions

> **Philosophy**: *"Give the field collector a weapon, not a dashboard."*

### Target Users

| Role | Description |
|------|-------------|
| **Collector** | Field staff collecting EMIs, savings deposits |
| **Supervisor** | Branch-level oversight, approval workflows |
| **Branch Manager** | Branch performance monitoring |
| **Area Manager** | Multi-branch analytics |

---

## ✨ Features

### Phase 1: Core Foundation ✅

<details>
<summary><b>📊 Database Schema</b></summary>

13 tables with Row Level Security:

| Table | Purpose |
|-------|---------|
| `branches` | Branch office management |
| `staff_profiles` | Staff info & assignments |
| `collections` | Core transaction records |
| `staff_locations` | GPS tracking logs |
| `activity_logs` | Complete audit trail |
| `staff_wallet` | Cash-in-hand tracking |
| `collection_targets` | Daily/weekly/monthly goals |
| `streaks` | Gamification data |
| `visit_logs` | Customer visit tracking |
| `breaks` | Rest period logging |
| `cash_deposits` | Cash drop at branch |
| `staff_notifications` | Push notifications |
| `notification_queue` | Offline notification queue |

</details>

<details>
<summary><b>🏗️ Models</b></summary>

- `StaffProfileModel` — Staff profile with role & status
- `CollectionModel` — Collection records with full metadata
- `WalletModel` — Cash & digital balance tracking
- `StreakModel` — Gamification streaks
- `TargetModel` — Performance targets
- `ActivityLogModel` — Audit trail entries
- `StaffLocationModel` — GPS coordinates

</details>

<details>
<summary><b>🔧 Repositories</b></summary>

**StaffRepository** methods:
- `getStaffProfile()` — Get staff details
- `getStaffWallet()` — Wallet balance
- `getStreakData()` — Gamification data
- `getTargets()` — Performance targets
- `updateLocation()` — GPS tracking
- `logActivity()` — Audit logging

**CollectionRepository** methods:
- `getTodayDueEmis()` — Today's collection list
- `searchCustomers()` — Search by name/phone/loan
- `getCustomerDetail()` — Customer 360° view
- `getCustomerLoans()` — Active loans
- `getCustomerSavings()` — Savings accounts
- `getCustomerCollectionHistory()` — Transaction history
- `recordCollection()` — Save collection
- `getRecentCollections()` — Recent activity
- `getFrequentCustomers()` — Top customers
- `getCollectionHistory()` — Historical records

</details>

<details>
<summary><b>📦 Providers</b></summary>

**Staff Providers**:
- `staffRepositoryProvider`
- `staffProfileProvider`
- `staffWalletProvider`
- `staffStreakProvider`
- `staffTargetsProvider`
- `staffLocationProvider`

**Collection Providers**:
- `collectionRepositoryProvider`
- `todayDueEmisProvider`
- `customerSearchProvider`
- `customerDetailProvider`
- `customerLoansProvider`
- `customerSavingsProvider`
- `customerCollectionHistoryProvider`
- `recentCollectionsProvider`
- `frequentCustomersProvider`
- `collectionHistoryProvider`
- `collectionNotifierProvider`

</details>

<details>
<summary><b>🎨 Widgets</b></summary>

| Widget | Purpose |
|--------|---------|
| `WalletCard` | Cash-in-hand display with actions |
| `TargetProgressRing` | Animated circular progress |
| `SyncStatusBar` | Network status indicator |
| `GpsStatusChip` | GPS accuracy display |
| `TodayAgendaList` | Daily collection preview |

</details>

---

### Phase 2: Essential Screens ✅

<details>
<summary><b>📄 Pages</b></summary>

| Page | Route | Description |
|------|-------|-------------|
| **Staff Home Dashboard** | `/staff/home` | Main dashboard with wallet, targets, agenda |
| **Collection List** | `/staff/collections` | Today's EMIs with filters & sorting |
| **Customer Search** | `/staff/search` | Search by name/phone/loan number |
| **Customer Detail** | `/staff/customer/:id` | 360° customer view (4 tabs) |
| **Collection History** | `/staff/history` | Past collections grouped by date |
| **Collection Form** | `/staff/collect/:loanId` | Record new collection |

</details>

<details>
<summary><b>🔍 Collection List Features</b></summary>

- **Filters**: All, Due Today, Overdue, Paid, Upcoming
- **Sorting**: Due Date, Amount (High/Low), Name, Distance
- **Pull-to-refresh** support
- **Quick collect** button on each tile
- **Status badges**: Paid, Partial, Pending, Overdue
- **Distance indicator** from current location

</details>

<details>
<summary><b>🔎 Customer Search Features</b></summary>

- **Multi-field search**: Name, Phone, Loan Number
- **Recent searches** (last 10)
- **Frequent customers** (top 5)
- **Quick actions**: Collect, View Details, Call
- **Empty state** with suggestions

</details>

<details>
<summary><b>👤 Customer Detail Features</b></summary>

**4 Tabs**:
1. **Overview** — Profile, KYC status, outstanding balance
2. **Loans** — Active loans with EMI schedules
3. **Savings** — Savings account details
4. **History** — Past transactions

**Actions**:
- Quick collect
- View on map
- Call customer
- View documents

</details>

<details>
<summary><b>📜 Collection History Features</b></summary>

- **Group by**: Date, Customer, Status
- **Date range filter**
- **Payment mode filter** (Cash, UPI, etc.)
- **Summary statistics**
- **Export to CSV** (planned)

</details>

---

### Phase 3: Field Operations ✅

<details>
<summary><b>🚨 Overdue Management</b></summary>

**Overdue List Page Features**:
- Days overdue badges (color-coded by severity)
- Quick filters: 1-7 days, 8-15 days, 16-30 days, 30+ days
- Sort by: Days, Amount, Name, Due Date
- Summary card with total overdue amount
- Quick actions: Call, Collect
- Penalty calculation display

**Color Coding**:
| Days | Color |
|------|-------|
| 1-7 | Orange |
| 8-15 | Deep Orange |
| 16-30 | Red |
| 30+ | Purple |

</details>

<details>
<summary><b>📍 Visit Check-in/Check-out</b></summary>

**Features**:
- GPS verification at check-in
- Visit purposes: Collection, Verification, Follow-up, Document, Other
- Optional notes
- Automatic activity logging
- Check-out with location capture
- Duration calculation

**Visit Status Tracking**:
- `in_progress` — Active visit
- `completed` — Finished visit
- `cancelled` — Cancelled visit

</details>

<details>
<summary><b>📊 Daily Summary</b></summary>

**Summary Metrics**:
- Total collected vs target
- Progress percentage
- Cash vs digital breakdown
- Visit count & success rate
- Distance traveled
- Average collection time
- Current streak days

**Features**:
- Date picker for historical summaries
- Share summary (text/CSV)
- Recent collections list
- Target achievement indicator

</details>

<details>
<summary><b>💰 Cash Deposit Flow</b></summary>

**Features**:
- Current wallet balance display
- Quick amount selection chips
- Deposit methods: Branch Counter, Cash Pickup
- Reference number entry
- Notes field
- "Deposit All" shortcut
- Wallet auto-update on success

**Deposit Status Flow**:
`pending_verification` → `verified` → `completed`

</details>

<details>
<summary><b>☕ Break/Rest Logging</b></summary>

**Break Types**:
| Type | Icon | Description |
|------|------|-------------|
| Lunch | 🍽️ | Meal break |
| Tea | ☕ | Short refreshment |
| Rest | 🛏️ | Rest period |
| Personal | 👤 | Personal matters |
| Other | ⋯ | Other reasons |

**Features**:
- Live elapsed time display
- Break history for today
- Automatic duration calculation
- Break time limits reminder

</details>

<details>
<summary><b>🔄 Offline Sync Engine</b></summary>

**Core Components**:
- `OfflineSyncEngine` — Main sync service
- `SyncStatusNotifier` — State management
- Queue-based operation storage

**Sync Features**:
- Queue operations when offline
- Automatic retry on failure
- Max 5 retry attempts per operation
- Sync status tracking (pending, syncing, synced, failed)
- Network status monitoring
- Cleanup of old synced items (24h TTL)

**Operation Types**:
- `insert` — New records
- `update` — Record updates
- `delete` — Record deletions

**Sync Status Provider**:
```dart
final syncStatus = ref.watch(syncStatusProvider);
// syncStatus.pending, syncStatus.success, syncStatus.failed
```

</details>

---

### Phase 4: Offline Engine ✅

<details>
<summary><b>💾 Local Database (Hive)</b></summary>

**Features**:
- Fast, encrypted local storage
- Collections, customers, loans caching
- Pending operations queue
- Settings persistence
- Last sync time tracking

**Storage Operations**:
| Operation | Description |
|-----------|-------------|
| `putCollection()` | Store collection locally |
| `getCollectionsForDate()` | Get collections by date |
| `searchCustomers()` | Local customer search |
| `getLoansForCustomer()` | Customer's loans |
| `addPendingOperation()` | Queue operation |
| `getStats()` | Storage statistics |

</details>

<details>
<summary><b>🔄 Background Sync Service</b></summary>

**Features**:
- Auto-sync every 5 minutes
- Manual sync trigger
- Network status detection
- Pull latest data from server
- Sync status streaming

**Sync Flow**:
1. Check network connectivity
2. Push pending operations
3. Pull latest server data
4. Update local cache
5. Record sync timestamp

**Sync Status Types**:
- `syncing` — Sync in progress
- `synced` — All data synced
- `offline` — No network
- `error` — Sync failed

</details>

<details>
<summary><b>⚔️ Conflict Resolution</b></summary>

**Conflict Types**:
| Type | Description |
|------|-------------|
| `updateUpdate` | Both local & server modified |
| `deleteUpdate` | Local deleted, server updated |
| `updateDelete` | Local updated, server deleted |
| `duplicate` | Duplicate records |

**Resolution Strategies**:
- `serverWins` — Server data takes priority
- `localWins` — Local data takes priority
- `merge` — Attempt to merge both
- `manual` — Require manual resolution

**Table Defaults**:
| Table | Strategy |
|-------|----------|
| collections | serverWins |
| staff_wallet | serverWins |
| members | merge |

</details>

<details>
<summary><b>📶 Offline Mode Indicator</b></summary>

**Features**:
- Top banner when offline
- Sync status display
- Pending count badge
- Quick sync button
- Status modal with details

**Status Colors**:
| Status | Color |
|--------|-------|
| Syncing | Blue |
| Synced | Green |
| Offline | Orange |
| Error | Red |
| Pending | Amber |

</details>

<details>
<summary><b>📋 Pending Operations View</b></summary>

**Features**:
- Grouped by table type
- Operation type icons (insert/update/delete)
- Attempt count display
- Remove operation option
- Sync all button
- Last sync timestamp

**Operation Types**:
| Type | Icon | Color |
|------|------|-------|
| Insert | ➕ | Green |
| Update | ✏️ | Blue |
| Delete | 🗑️ | Red |

</details>

---

### Phase 5: Gamification ✅

<details>
<summary><b>🔥 Streak Tracking</b></summary>

**Features**:
- Current streak display with fire animation
- Longest streak record
- 7-day visual calendar
- Streak protection (1 grace day)
- Streak recovery mechanics

**Streak Rules**:
- Collect at least once per day to maintain streak
- 1 grace day per month for emergencies
- Streak breaks at midnight if no collection

**Streak Milestones**:
| Days | Badge |
|------|-------|
| 3 | Hat Trick |
| 7 | Week Warrior |
| 30 | Monthly Master |
| 100 | Streak Legend |

</details>

<details>
<summary><b>🏆 Achievements System</b></summary>

**Achievement Types**:
| Type | Description |
|------|-------------|
| Collection | Total collections count |
| Streak | Consecutive collection days |
| Target | Daily target achievements |
| Visit | Customer visit counts |
| Speed | Fast collections |
| Accuracy | Collection precision |

**Achievement Tiers**:
- 🥉 **Bronze** — Starting achievements
- 🥈 **Silver** — Intermediate goals
- 🥇 **Gold** — Significant milestones
- 💎 **Platinum** — Major achievements
- 💠 **Diamond** — Legendary status

**Points System**:
- Each achievement earns points
- Points contribute to leaderboard
- Bonus points for target achievements
- Daily collection = +5 points

</details>

<details>
<summary><b>📊 Leaderboard</b></summary>

**Leaderboard Periods**:
| Period | Description |
|--------|-------------|
| Today | Daily rankings |
| This Week | Weekly competition |
| This Month | Monthly top performers |
| All Time | Historical best |

**Leaderboard Metrics**:
- Total collected amount
- Collections count
- Visit count
- Target achievement %
- Current streak

**Features**:
- Top 3 podium display
- User's current rank highlight
- View full leaderboard
- Filter by period

</details>

<details>
<summary><b>🎯 Daily Targets</b></summary>

**Features**:
- Circular progress indicator
- Real-time progress updates
- Target achieved celebration
- Over-achievement bonus points

**Gamification Dashboard**:
- Streak header with animated fire
- Today's target progress ring
- Quick stats (Collected, Visits)
- Achievement badges carousel
- Leaderboard preview
- Motivational quotes

</details>

<details>
<summary><b>💡 Motivational Features</b></summary>

**Motivational Quotes**:
- Random daily motivation
- Context-aware suggestions
- Achievement celebration messages

**Visual Feedback**:
- Animated fire icon for streaks
- Pulsing effects for active elements
- Confetti on achievements
- Progress animations

**Social Elements**:
- Compare with peers
- Branch-level competition
- Team challenges (planned)

</details>

---

### Phase 6: Admin Integration ✅

<details>
<summary><b>📋 Audit Logs</b></summary>

**Audit Log Model**:
- Comprehensive action tracking
- Entity type and ID linkage
- GPS coordinates for each action
- IP address and user agent
- Timestamp for all activities

**Audit Actions**:
| Category | Actions |
|----------|---------|
| Authentication | login, logout, loginFailed |
| Collections | create, update, delete, sync |
| Visits | checkIn, checkOut |
| Wallet | deposit, withdraw |
| Profile | update, passwordChange, pinChange |
| Location | update, tracking start/stop |
| Admin | approval, rejection, target set |

</details>

---

### Phase 7: Security & Audit ✅

<details>
<summary><b>🔒 Security Features</b></summary>

**Authentication**:
- PIN code protection
- Biometric authentication (fingerprint, face)
- Auto-lock after inactivity
- Last activity tracking

**Security Settings**:
| Setting | Options |
|---------|---------|
| PIN | 4-6 digit code |
| Biometric | Fingerprint, Face ID |
| Auto-lock | 1, 5, 15, 30 minutes |

**Security Service Methods**:
- `setPin()` / `verifyPin()`
- `authenticateWithBiometrics()`
- `isBiometricAvailable()`
- `shouldLockDueToInactivity()`

</details>

---

### Phase 8: Communication ✅

<details>
<summary><b>📱 Notifications</b></summary>

**Notification Types**:
- Collection reminders
- Target achievements
- Overdue alerts
- Streak milestones
- System announcements

**Features**:
- Push notifications
- In-app notification center
- Notification preferences
- Do not disturb mode

</details>

---

### Phase 9: Analytics & Reports ✅

<details>
<summary><b>📊 Analytics Dashboard</b></summary>

**Summary Cards**:
- Total Collected (with % change)
- Collections Count
- Average Collection Amount

**Period Filters**:
| Period | Description |
|--------|-------------|
| Day | Today's performance |
| Week | This week summary |
| Month | Monthly trends |
| Year | Yearly overview |

**Performance Metrics**:
- Target Achievement %
- On-time Collection Rate
- Customer Satisfaction Score
- Visit Success Rate

**Visualizations**:
- Collection trend chart
- Progress indicators
- Top customers list

**Reports**:
- Daily collection reports
- Weekly performance summary
- Monthly analytics
- Export to CSV/PDF (planned)

</details>

---

## 🎉 All Phases Complete!

---

## 📸 Screenshots

*Screenshots will be added after UI implementation*

---

## 🏗️ Architecture

### Clean Architecture (Feature-First)

```
lib/
├── core/                    # Shared infrastructure
│   ├── constants/           # App constants, colors, enums
│   ├── services/            # Global services (GPS, sync, etc.)
│   ├── utils/               # Helpers, formatters, validators
│   ├── widgets/             # Shared UI components
│   └── providers/           # Global providers (Supabase, etc.)
│
├── features/
│   ├── auth/                # Authentication module
│   ├── home/                # Home & Dashboard
│   ├── loans/               # Loan management
│   ├── savings/             # Savings management
│   └── staff/               # Staff Portal (NEW)
│       ├── data/
│       │   ├── models/      # Data models
│       │   ├── repositories/# Data access
│       │   └── providers/   # State providers
│       └── presentation/
│           ├── pages/       # Screen widgets
│           └── widgets/     # UI components
│
└── main.dart
```

### State Management

- **Riverpod 2.4+** for all state
- `StateProvider` for simple state
- `FutureProvider` for async data
- `StateNotifierProvider` for complex state
- `Provider.family` for parameterized providers

### Navigation

- **GoRouter 14+** for declarative routing
- Deep link support
- Auth-guarded routes

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.11+ |
| **Language** | Dart 3.1+ |
| **Backend** | Supabase (PostgreSQL) |
| **Auth** | Supabase Auth |
| **State** | Riverpod 2.4+ |
| **Navigation** | GoRouter 14+ |
| **Location** | Geolocator 13+ |
| **UI Utils** | Pull to Refresh, Intl |

### Platforms Supported

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux

---

## 📁 Project Structure

```
finance_app_zo/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart
│   │   │   └── enums.dart
│   │   ├── services/
│   │   │   └── location_service.dart
│   │   ├── utils/
│   │   │   └── formatters.dart
│   │   ├── widgets/
│   │   │   ├── glass_card.dart
│   │   │   └── shimmer_loading.dart
│   │   └── providers/
│   │       └── supabase_provider.dart
│   │
│   └── features/
│       ├── staff/                    # STAFF PORTAL MODULE
│       │   ├── data/
│       │   │   ├── models/
│       │   │   │   ├── staff_profile_model.dart
│       │   │   │   ├── collection_model.dart
│       │   │   │   ├── wallet_model.dart
│       │   │   │   ├── streak_model.dart
│       │   │   │   ├── target_model.dart
│       │   │   │   ├── activity_log_model.dart
│       │   │   │   └── staff_location_model.dart
│       │   │   ├── repositories/
│       │   │   │   ├── staff_repository.dart
│       │   │   │   └── collection_repository.dart
│       │   │   └── providers/
│       │   │       ├── staff_providers.dart
│       │   │       └── collection_providers.dart
│       │   └── presentation/
│       │       ├── pages/
│       │       │   ├── staff_home_dashboard.dart
│       │       │   ├── collection_list_page.dart
│       │       │   ├── customer_search_page.dart
│       │       │   ├── customer_detail_page.dart
│       │       │   ├── collection_history_page.dart
│       │       │   └── collection_form_page.dart
│       │       └── widgets/
│       │           ├── wallet_card.dart
│       │           ├── target_progress_ring.dart
│       │           ├── sync_status_bar.dart
│       │           ├── gps_status_chip.dart
│       │           ├── today_agenda_list.dart
│       │           ├── collection_list_tile.dart
│       │           └── collection_filter_widgets.dart
│       │
│       ├── auth/
│       ├── home/
│       ├── loans/
│       └── savings/
│
├── supabase_schema.sql            # Original schema
├── supabase_staff_schema.sql      # Staff portal schema
├── AGENTS.md                      # AI agent instructions
├── README.md                      # This file
└── pubspec.yaml
```

---

## 🗄️ Database Schema

### Core Tables (Staff Portal)

```sql
-- Staff Profile
CREATE TABLE staff_profiles (
    id UUID PRIMARY KEY,
    staff_id TEXT UNIQUE NOT NULL,
    branch_id UUID REFERENCES branches(id),
    role TEXT CHECK (role IN ('collector', 'supervisor', 'branch_manager', 'area_manager')),
    status TEXT DEFAULT 'active',
    phone TEXT,
    name TEXT NOT NULL,
    email TEXT,
    -- ... additional fields
);

-- Collections (Core Transaction Table)
CREATE TABLE collections (
    id UUID PRIMARY KEY,
    staff_id UUID REFERENCES staff_profiles(id),
    member_id UUID REFERENCES members(id),
    loan_id UUID REFERENCES loans(id),
    savings_id UUID REFERENCES savings(id),
    
    -- Amounts
    amount_expected DECIMAL(12,2),
    amount_collected DECIMAL(12,2) NOT NULL,
    
    -- Metadata
    payment_mode TEXT CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer', 'cheque', 'card')),
    collection_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    gps_accuracy DECIMAL(8,2),
    
    -- Sync
    sync_status TEXT DEFAULT 'pending',
    synced_at TIMESTAMP WITH TIME ZONE,
    
    -- Audit
    notes TEXT,
    is_partial BOOLEAN DEFAULT FALSE,
    collector_confirmed BOOLEAN DEFAULT FALSE,
    member_confirmed BOOLEAN DEFAULT FALSE
);

-- Staff Wallet (Cash-in-Hand)
CREATE TABLE staff_wallet (
    id UUID PRIMARY KEY,
    staff_id UUID REFERENCES staff_profiles(id),
    cash_in_hand DECIMAL(12,2) DEFAULT 0,
    digital_balance DECIMAL(12,2) DEFAULT 0,
    total_collected_today DECIMAL(12,2) DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Activity Logs (Audit Trail)
CREATE TABLE activity_logs (
    id UUID PRIMARY KEY,
    staff_id UUID,
    action TEXT NOT NULL,
    entity_type TEXT,
    entity_id UUID,
    metadata JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Row Level Security (RLS)

All tables have RLS enabled:
- Staff can only access their own data
- Supervisors can view branch-level data
- Managers have area-level access

```sql
-- Example RLS Policy
CREATE POLICY "Staff own data" ON collections
    FOR ALL USING (staff_id = auth.uid());
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.11+
- Dart SDK 3.1+
- Supabase account (free tier works)
- Android Studio / VS Code

### Installation

```bash
# Clone the repository
git clone https://github.com/sansayan01/finance_app_zo.git
cd finance_app_zo

# Install dependencies
flutter pub get

# Set up Supabase
# 1. Create a Supabase project
# 2. Run supabase_schema.sql in SQL Editor
# 3. Run supabase_staff_schema.sql in SQL Editor
# 4. Copy your Supabase URL and anon key

# Create .env file
echo "SUPABASE_URL=your_url" > .env
echo "SUPABASE_ANON_KEY=your_key" >> .env

# Run the app
flutter run
```

### Environment Variables

Create a `.env` file in the project root:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

---

## 📊 Implementation Status

| Phase | Name | Status | Progress |
|-------|------|--------|----------|
| **1** | Core Foundation | ✅ Complete | 100% |
| **2** | Essential Screens | ✅ Complete | 100% |
| **3** | Field Operations | ✅ Complete | 100% |
| **4** | Offline Engine | ✅ Complete | 100% |
| **5** | Gamification | ✅ Complete | 100% |
| **6** | Admin Integration | ✅ Complete | 100% |
| **7** | Security & Audit | ✅ Complete | 100% |
| **8** | Communication | ✅ Complete | 100% |
| **9** | Analytics & Reports | ✅ Complete | 100% |

---

## 📡 API Reference

### Collection APIs

```dart
// Get today's due EMIs
final emis = await ref.read(todayDueEmisProvider(staffId).future);

// Search customers
final results = await ref.read(customerSearchProvider('query').future);

// Get customer detail
final customer = await ref.read(customerDetailProvider(customerId).future);

// Record collection
await ref.read(collectionNotifierProvider.notifier).recordCollection(
  loanId: loanId,
  amount: 500.0,
  paymentMode: PaymentMode.cash,
  latitude: 22.57,
  longitude: 88.36,
);
```

### Staff APIs

```dart
// Get staff profile
final profile = await ref.read(staffProfileProvider(staffId).future);

// Get wallet balance
final wallet = await ref.read(staffWalletProvider(staffId).future);

// Get streak data
final streak = await ref.read(staffStreakProvider(staffId).future);

// Get targets
final targets = await ref.read(staffTargetsProvider(staffId).future);
```

---

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Sayan** - [@sansayan01](https://github.com/sansayan01)

---

<div align="center">
  <p>Built with ❤️ for MFI Field Collectors</p>
  <p>© 2024-2026 MicroFlow Pro</p>
</div>
