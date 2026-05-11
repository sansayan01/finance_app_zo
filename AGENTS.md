# MicroFlow Pro - Staff Portal

## Project Overview

MicroFlow Pro is a **Flutter cross-platform financial management app** for MFIs (Micro-Finance Institutions) and savings groups. The Staff Portal is specifically designed for **field collectors** who work in villages with poor network conditions.

## Architecture

- **Flutter 3.11+ / Dart 3.1+**
- **Supabase** - Backend (auth + database, NO file storage)
- **Riverpod** - State management
- **Go Router** - Navigation
- **Clean Architecture** - Feature-first organization

## Key Design Decisions

| Decision | Choice |
|----------|--------|
| **No image storage** | Metadata only - fully auditable |
| **No audio notes** | Not required for MFI compliance |
| **Offline-first** | Collections save locally, sync when online |
| **GPS on every collection** | Mandatory for audit trail |
| **Receipt format** | On-screen widget, not image/PDF |

## Staff Portal Structure

```
lib/features/staff/
├── data/
│   ├── models/
│   │   ├── staff_profile_model.dart      ✅ Created
│   │   ├── collection_model.dart          ✅ Created
│   │   ├── wallet_model.dart              ✅ Created
│   │   ├── streak_model.dart              ✅ Created
│   │   ├── target_model.dart              ✅ Created
│   │   ├── activity_log_model.dart        ✅ Created
│   │   └── staff_location_model.dart      ✅ Created
│   ├── repositories/
│   │   ├── staff_repository.dart          ✅ Created
│   │   └── collection_repository.dart     ✅ Updated (Phase 2)
│   └── providers/
│       ├── staff_providers.dart           ✅ Created
│       └── collection_providers.dart      ✅ Updated (Phase 2)
└── presentation/
    ├── pages/
    │   ├── staff_home_dashboard.dart      ✅ Created
    │   ├── collection_form_page.dart      ✅ Created
    │   ├── collection_list_page.dart      ✅ Created (Phase 2)
    │   ├── customer_search_page.dart      ✅ Created (Phase 2)
    │   ├── customer_detail_page.dart      ✅ Created (Phase 2)
    │   └── collection_history_page.dart   ✅ Created (Phase 2)
    └── widgets/
        ├── wallet_card.dart               ✅ Created
        ├── target_progress_ring.dart      ✅ Created
        ├── sync_status_bar.dart           ✅ Created
        ├── gps_status_chip.dart           ✅ Created
        ├── today_agenda_list.dart         ✅ Created
        ├── collection_list_tile.dart      ✅ Created (Phase 2)
        └── collection_filter_widgets.dart ✅ Created (Phase 2)
```

## Database Schema

Run these files in Supabase SQL Editor:
1. `supabase_schema.sql` - Base tables (members, loans, savings, etc.)
2. `supabase_staff_schema.sql` - Staff portal tables ✅ Created

### New Tables Created

| Table | Purpose |
|-------|---------|
| `branches` | Branch offices |
| `staff_profiles` | Staff information and assignments |
| `collections` | Field collections (core table) |
| `savings_collections` | Savings deposit collections |
| `staff_locations` | GPS tracking logs |
| `activity_logs` | Audit trail |
| `staff_wallet` | Cash in hand tracking |
| `wallet_transactions` | Wallet transaction history |
| `collection_targets` | Daily/weekly/monthly targets |
| `visit_logs` | Customer visit tracking |
| `offline_sync_queue` | Offline sync management |
| `staff_streaks` | Gamification streaks |
| `staff_notifications` | Staff notifications |

### RLS Policies

All tables have Row Level Security enabled:
- Staff can only read/update their own data
- Supervisors can read branch-level data
- Collections are filtered by staff_id

### Triggers

- Auto-create wallet on staff creation
- Auto-create streak record on staff creation
- Update wallet balance on collection
- Update loan schedule on collection
- Update target progress on collection
- Update streak on collection

## Implementation Status

### ✅ Completed (Phase 1 - Core Foundation)

- [x] Database schema design (13 tables)
- [x] Staff profile model
- [x] Collection model
- [x] Wallet model
- [x] Streak model
- [x] Target model
- [x] Activity log model
- [x] Staff location model
- [x] Staff repository
- [x] Collection repository
- [x] Staff providers
- [x] Collection providers
- [x] Wallet card widget
- [x] Target progress ring widget
- [x] Sync status bar widget
- [x] GPS status chip widget
- [x] Today's agenda list widget
- [x] Staff home dashboard
- [x] Collection form page

### ✅ Completed (Phase 2 - Essential Screens)

- [x] Collection list page with filters & sorting
- [x] Collection list tile widget
- [x] Collection filter widgets (filter chips, sort dropdown, area filter)
- [x] Customer search page
- [x] Customer detail page (360° view with tabs)
- [x] Collection history page
- [x] Recent searches provider
- [x] Frequent customers provider
- [x] Customer search provider
- [x] Customer detail/loans/savings providers
- [x] Customer collection history provider
- [x] Collection history provider (with date/type/payment filters)
- [x] Repository methods: searchCustomers, getCustomerDetail, getCustomerLoans, getCustomerSavings, getCustomerCollectionHistory, getRecentCollections, getFrequentCustomers

### 🟡 Next Steps (Phase 3 - Field Operations)

1. **Overdue Management Page** - Dedicated overdue list with escalation
2. **Visit Check-in/Check-out** - GPS-based visit logging
3. **Daily Summary Page** - End-of-day report with totals
4. **Offline Sync Engine** - Local queue, retry logic, conflict resolution
5. **Cash Deposit Flow** - Record branch deposit with supervisor verification
6. **Break/Rest Logging** - Track breaks for compliance

### 🟢 Phase 4-9 (Future)

- [ ] Gamification (streaks UI, badges, leaderboard)
- [ ] Maps & Location (map view, route optimization)
- [ ] Notifications (push, supervisor messages)
- [ ] Analytics (charts, reports)
- [ ] Polish & QA (error handling, tests)
- [ ] Production (security audit, deployment)

## Routes Structure

```
/staff                    → Staff Home Dashboard
/staff/collections        → Collection List Page
/staff/collections?filter=overdue → Overdue Collections
/staff/search             → Customer Search Page
/staff/customer/:id       → Customer Detail Page
/staff/customer/:id/history → Customer Collection History
/staff/collect            → Collection Form Page
/staff/collect?customerId=xxx → Pre-filled Collection Form
/staff/history            → Collection History Page
/staff/loan/:id/schedule  → Loan Schedule View
/staff/savings/:id        → Savings Detail View
```

## Running the App

```bash
# Get dependencies
flutter pub get

# Run on device
flutter run

# Build for production
flutter build apk --release
flutter build ios --release
```

## Testing the Schema

1. Go to Supabase SQL Editor
2. Run `supabase_schema.sql` first
3. Run `supabase_staff_schema.sql` second
4. Verify tables created with:
   ```sql
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public' 
   ORDER BY table_name;
   ```

## Key Widgets Usage

### Wallet Card
```dart
WalletCard(
  wallet: walletModel,
  onDeposit: () => showDepositSheet(),
)
```

### Target Progress Ring
```dart
TargetProgressRing(
  target: targetModel,
  streak: streakModel,
  size: 180,
  onTap: () => navigateToTargets(),
)
```

### Sync Status Bar
```dart
SyncStatusBar(
  status: SyncStatus.synced,
  pendingCount: 0,
  lastSyncAt: DateTime.now(),
  onSyncTap: () => manualSync(),
)
```

### GPS Status Chip
```dart
GpsStatusChip(
  status: GpsStatus.active,
  accuracy: 15,
  onTap: () => requestLocationPermission(),
)
```

### Collection List Tile
```dart
CollectionListTile(
  emi: emiData,
  isOverdue: true,
  onTap: () => navigateToDetail(),
  onQuickCollect: () => showCollectionForm(),
)
```

### Collection Filter Chips
```dart
CollectionFilterChip(
  filter: CollectionFilter.overdue,
  isSelected: true,
  count: 5,
  onTap: () => setFilter(),
)
```

## Notes

- All collections require GPS coordinates
- Sync status is tracked per record
- Streaks are calculated automatically
- Wallet updates happen via database triggers
- No images/audio stored - metadata only
- Customer search supports name, phone, and loan number
- Collection history can be grouped by date or customer

## Dependencies

Add these to `pubspec.yaml`:

```yaml
dependencies:
  pull_to_refresh: ^2.0.0
  intl: ^0.19.0
  geolocator: ^13.0.0
  flutter_riverpod: ^2.4.0
  go_router: ^14.0.0
  supabase_flutter: ^2.0.0
  equatable: ^2.0.5
```
