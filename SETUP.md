# Staff Portal Setup Checklist

## 1. Supabase Setup

Run these SQL files in your Supabase SQL Editor (in order):
1. `supabase_schema.sql` - Original schema (if not done)
2. `supabase_staff_schema.sql` - Staff portal schema

## 2. main.dart Updates

Add Hive initialization before `runApp()`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_ANON_KEY',
  );
  
  // Initialize Hive for offline storage
  await Hive.initFlutter();
  
  runApp(const ProviderScope(child: MyApp()));
}
```

## 3. GoRouter Updates

Add these routes to your router configuration:

```dart
GoRoute(
  path: '/staff/home',
  builder: (context, state) => const StaffHomeDashboard(),
),
GoRoute(
  path: '/staff/collections',
  builder: (context, state) => const CollectionListPage(),
),
GoRoute(
  path: '/staff/search',
  builder: (context, state) => const CustomerSearchPage(),
),
GoRoute(
  path: '/staff/customer/:id',
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return CustomerDetailPage(customerId: id);
  },
),
GoRoute(
  path: '/staff/collect/:loanId',
  builder: (context, state) {
    final loanId = state.pathParameters['loanId']!;
    return CollectionFormPage(loanId: loanId);
  },
),
GoRoute(
  path: '/staff/history',
  builder: (context, state) => const CollectionHistoryPage(),
),
GoRoute(
  path: '/staff/overdue',
  builder: (context, state) => const OverdueListPage(),
),
GoRoute(
  path: '/staff/visit',
  builder: (context, state) => const VisitCheckinPage(),
),
GoRoute(
  path: '/staff/summary',
  builder: (context, state) => const DailySummaryPage(),
),
GoRoute(
  path: '/staff/deposit',
  builder: (context, state) => const CashDepositPage(),
),
GoRoute(
  path: '/staff/break',
  builder: (context, state) => const BreakLoggingPage(),
),
GoRoute(
  path: '/staff/pending',
  builder: (context, state) => const PendingOperationsPage(),
),
GoRoute(
  path: '/staff/gamification',
  builder: (context, state) => const GamificationDashboard(),
),
GoRoute(
  path: '/staff/analytics',
  builder: (context, state) => const AnalyticsDashboard(),
),
```

## 4. Run Flutter Commands

```bash
# Get dependencies
flutter pub get

# Run code generation (if using build_runner)
flutter pub run build_runner build --delete-conflicting-outputs

# Analyze for errors
flutter analyze

# Run the app
flutter run
```

## 5. Test Checklist

- [ ] Staff can log in
- [ ] Dashboard shows wallet, target, streak
- [ ] Collection list loads today's EMIs
- [ ] Customer search works
- [ ] Collection form submits with GPS
- [ ] Offline mode indicator shows when disconnected
- [ ] Sync works when reconnected
- [ ] Visit check-in captures location
- [ ] Gamification shows streak & achievements

## 6. Known Issues to Fix

### Missing Imports
Some files may need these imports added:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
```

### Provider References
If you get "Provider not found" errors:
- Check that the provider is exported from its file
- Check that you're importing the correct file

### Supabase Table Names
If queries fail:
- Verify table names match schema exactly
- Check RLS policies are correct
- Verify your user has the right permissions

## 7. Quick Fixes

### If "Hive not initialized":
```dart
// In main.dart, before runApp
await Hive.initFlutter();
```

### If "Supabase not initialized":
```dart
// In main.dart, before runApp
await Supabase.initialize(
  url: 'YOUR_URL',
  anonKey: 'YOUR_KEY',
);
```

### If GPS permissions fail:
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Add to `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location to record collection points</string>
```

## 8. Architecture Notes

- All state uses Riverpod
- All navigation uses GoRouter
- All backend calls go through repositories
- All UI is in presentation layer
- Models are immutable with Equatable

---

## Need Help?

Run these commands to debug:
```bash
flutter analyze           # Find syntax errors
flutter pub get          # Install dependencies
flutter clean            # Clean build cache
flutter pub upgrade      # Update dependencies
```
