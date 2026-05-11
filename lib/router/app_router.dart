import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Auth
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/data/models/user_model.dart';

// Admin Portal
import '../features/home/presentation/pages/home_page.dart';
import '../features/loans/presentation/pages/loans_page.dart';
import '../features/savings/presentation/pages/savings_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/settings/presentation/pages/profile_page.dart';
import '../features/settings/presentation/pages/activity_logs_page.dart';
import '../core/widgets/hud_navigation.dart';
import '../features/loans/presentation/pages/loan_detail_page.dart';
import '../features/loans/presentation/pages/new_loan_page.dart';
import '../features/savings/presentation/pages/new_recurring_saving_page.dart';
import '../features/savings/presentation/pages/saving_detail_page.dart';
import '../features/users/presentation/pages/users_page.dart';
import '../features/users/presentation/pages/new_user_page.dart';
import '../features/users/presentation/pages/user_details_page.dart';
import '../features/analytics/presentation/pages/analytics_page.dart';
import '../features/home/presentation/pages/search_page.dart';
import '../features/home/presentation/pages/notifications_page.dart';
import '../features/transactions/presentation/pages/transactions_page.dart';
import '../features/members/presentation/pages/member_onboarding_page.dart';

// Staff Portal - NEW
import '../features/staff/presentation/pages/staff_home_dashboard.dart';
import '../features/staff/presentation/pages/collection_form_page.dart';
import '../features/staff/presentation/pages/collection_list_page.dart';
import '../features/staff/presentation/pages/customer_search_page.dart';
import '../features/staff/presentation/pages/customer_detail_page.dart';
import '../features/staff/presentation/pages/collection_history_page.dart';
import '../features/staff/presentation/pages/overdue_list_page.dart';
import '../features/staff/presentation/pages/visit_checkin_page.dart';
import '../features/staff/presentation/pages/daily_summary_page.dart';
import '../features/staff/presentation/pages/cash_deposit_page.dart';
import '../features/staff/presentation/pages/break_logging_page.dart';
import '../features/staff/presentation/pages/pending_operations_page.dart';
import '../features/staff/presentation/pages/gamification_dashboard.dart';
import '../features/staff/presentation/providers/sync_status_provider.dart';

// =====================================================
// AUTH REDIRECT LISTENER
// =====================================================
class AuthRedirectListener extends ChangeNotifier {
  final Ref ref;

  AuthRedirectListener(this.ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      notifyListeners();
    });
  }

  bool get isAuthenticated =>
      ref.read(authProvider).status == AuthStatus.authenticated;
}

final authRedirectListenerProvider = Provider<AuthRedirectListener>((ref) {
  return AuthRedirectListener(ref);
});

// =====================================================
// ROUTER PROVIDER
// =====================================================
final routerProvider = Provider<GoRouter>((ref) {
  final authListener = ref.watch(authRedirectListenerProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authListener,
    redirect: (context, state) {
      final authStatus = ref.read(authProvider).status;
      final isAuthenticated = authStatus == AuthStatus.authenticated;
      final isAuthPath = state.matchedLocation.startsWith('/auth');

      if (!isAuthenticated && !isAuthPath) {
        return '/auth';
      }

      if (isAuthenticated && isAuthPath) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth Shell
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthShell(),
      ),

      // Admin Shell (for admins/managers)
      ShellRoute(
        builder: (context, state, child) {
          return AdminShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePageContent(),
          ),
          GoRoute(
            path: '/loans',
            builder: (context, state) => const LoansPage(),
          ),
          GoRoute(
            path: '/loans/new',
            builder: (context, state) => const NewLoanPage(),
          ),
          GoRoute(
            path: '/loans/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return LoanDetailPage(loanId: id);
            },
          ),
          GoRoute(
            path: '/savings',
            builder: (context, state) => const SavingsPage(),
          ),
          GoRoute(
            path: '/savings/new',
            builder: (context, state) => const NewRecurringSavingPage(),
          ),
          GoRoute(
            path: '/savings/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return SavingDetailPage(savingId: id);
            },
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersPage(),
          ),
          GoRoute(
            path: '/users/new',
            builder: (context, state) => const NewUserPage(),
          ),
          GoRoute(
            path: '/users/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return UserDetailsPage(userId: id);
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
            routes: [
              GoRoute(
                path: 'profile',
                builder: (context, state) => const ProfilePage(),
              ),
              GoRoute(
                path: 'logs',
                builder: (context, state) => const ActivityLogsPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsPage(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsPage(),
          ),
          GoRoute(
            path: '/members/onboarding',
            builder: (context, state) => const MemberOnboardingPage(),
          ),
        ],
      ),

      // Staff Shell (for field collectors) - NEW
      ShellRoute(
        builder: (context, state, child) {
          return StaffShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/staff',
            builder: (context, state) => const StaffHomeDashboard(),
          ),
          GoRoute(
            path: '/staff/collections',
            builder: (context, state) => const CollectionListPage(),
          ),
          GoRoute(
            path: '/staff/collection/:loanId',
            builder: (context, state) {
              final loanId = state.pathParameters['loanId']!;
              final customerId = state.uri.queryParameters['customerId'];
              return CollectionFormPage(
                loanId: loanId,
                customerId: customerId,
              );
            },
          ),
          GoRoute(
            path: '/staff/customers',
            builder: (context, state) => const CustomerSearchPage(),
          ),
          GoRoute(
            path: '/staff/customers/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CustomerDetailPage(customerId: id);
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
        ],
      ),
    ],
  );
});

// =====================================================
// AUTH SHELL
// =====================================================
class AuthShell extends StatefulWidget {
  const AuthShell({super.key});

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  bool _showLogin = true;

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return LoginPage(
        onSignUpTap: () => setState(() => _showLogin = false),
      );
    } else {
      return SignUpPage(
        onSignInTap: () => setState(() => _showLogin = true),
      );
    }
  }
}

// =====================================================
// HOME PAGE CONTENT - ROLE-BASED REDIRECT
// =====================================================
class HomePageContent extends ConsumerWidget {
  const HomePageContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // Redirect staff to their dashboard
    if (user?.role == UserRole.fieldStaff) {
      // Use WidgetsBinding to avoid navigation during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/staff');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Admin/Manager dashboard
    return HomePage(
      onViewAllLoans: () => context.go('/loans'),
      onViewAllSavings: () => context.go('/savings'),
      onQuickAction: () {},
    );
  }
}

// =====================================================
// ADMIN SHELL
// =====================================================
class AdminShell extends StatelessWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/loans')) return 1;
    if (location.startsWith('/savings')) return 2;
    if (location.startsWith('/users')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/loans');
        break;
      case 2:
        context.go('/savings');
        break;
      case 3:
        context.go('/users');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final useHudNav = MediaQuery.of(context).size.width >= 600;
    final currentIndex = _calculateSelectedIndex(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          child,
          if (useHudNav)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Center(
                child: HUDNavigation(
                  currentIndex: currentIndex,
                  onTap: (index) => _onItemTapped(index, context),
                  items: const [
                    HUDNavItem(
                        label: 'Dashboard',
                        icon: Icons.grid_view_outlined,
                        activeIcon: Icons.grid_view_rounded),
                    HUDNavItem(
                        label: 'Loans',
                        icon: Icons.account_balance_outlined,
                        activeIcon: Icons.account_balance_rounded),
                    HUDNavItem(
                        label: 'Savings',
                        icon: Icons.account_balance_wallet_outlined,
                        activeIcon: Icons.account_balance_wallet_rounded),
                    HUDNavItem(
                        label: 'Users',
                        icon: Icons.manage_accounts_outlined,
                        activeIcon: Icons.manage_accounts_rounded),
                    HUDNavItem(
                        label: 'Settings',
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings_rounded),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: useHudNav
          ? null
          : _PremiumBottomBar(
              currentIndex: currentIndex,
              onTap: (index) => _onItemTapped(index, context),
            ),
    );
  }
}

// =====================================================
// STAFF SHELL - NEW
// =====================================================
class StaffShell extends ConsumerWidget {
  final Widget child;

  const StaffShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/staff/collections') ||
        location.startsWith('/staff/collection')) return 1;
    if (location.startsWith('/staff/customers')) return 2;
    if (location.startsWith('/staff/history')) return 3;
    if (location.startsWith('/staff/pending')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/staff');
        break;
      case 1:
        context.go('/staff/collections');
        break;
      case 2:
        context.go('/staff/customers');
        break;
      case 3:
        context.go('/staff/history');
        break;
      case 4:
        context.go('/staff/pending');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _calculateSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    // Get pending operations count
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingCount = syncStatus.pending;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: child,
      bottomNavigationBar: StaffBottomBar(
        currentIndex: currentIndex,
        onTap: (index) => _onItemTapped(index, context),
        pendingCount: pendingCount,
        isDark: isDark,
        primary: primary,
      ),
    );
  }
}

// =====================================================
// STAFF BOTTOM BAR - NEW
// =====================================================
class StaffBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int pendingCount;
  final bool isDark;
  final Color primary;

  const StaffBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.pendingCount,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E2A).withOpacity(0.95)
                : Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StaffNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                currentIndex: currentIndex,
                primary: primary,
                isDark: isDark,
                onTap: onTap,
              ),
              _StaffNavItem(
                index: 1,
                icon: Icons.playlist_add_check_outlined,
                activeIcon: Icons.playlist_add_check_rounded,
                label: 'Today',
                currentIndex: currentIndex,
                primary: primary,
                isDark: isDark,
                onTap: onTap,
              ),
              _StaffNavItem(
                index: 2,
                icon: Icons.person_search_outlined,
                activeIcon: Icons.person_search_rounded,
                label: 'Customers',
                currentIndex: currentIndex,
                primary: primary,
                isDark: isDark,
                onTap: onTap,
              ),
              _StaffNavItem(
                index: 3,
                icon: Icons.history_outlined,
                activeIcon: Icons.history_rounded,
                label: 'History',
                currentIndex: currentIndex,
                primary: primary,
                isDark: isDark,
                onTap: onTap,
              ),
              _StaffNavItem(
                index: 4,
                icon: Icons.sync_problem_outlined,
                activeIcon: Icons.sync_rounded,
                label: 'Sync',
                currentIndex: currentIndex,
                primary: primary,
                isDark: isDark,
                onTap: onTap,
                badge: pendingCount > 0 ? pendingCount.toString() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffNavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int currentIndex;
  final Color primary;
  final bool isDark;
  final ValueChanged<int> onTap;
  final String? badge;

  const _StaffNavItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.currentIndex,
    required this.primary,
    required this.isDark,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    final inactiveColor = isDark
        ? Colors.white.withOpacity(0.4)
        : Colors.black.withOpacity(0.4);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withOpacity(isDark ? 0.2 : 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? primary : inactiveColor,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? primary : inactiveColor,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                right: 8,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// PREMIUM BOTTOM BAR (Admin)
// =====================================================
class _PremiumBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PremiumBottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3E3E4A).withOpacity(0.85)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(isDark ? 0.15 : 0.4),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.25)
                      : Colors.white.withOpacity(0.5),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.6 : 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                      index: 0,
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Home',
                      currentIndex: currentIndex,
                      primary: primary,
                      isDark: isDark,
                      onTap: onTap),
                  _NavItem(
                      index: 1,
                      icon: Icons.account_balance_outlined,
                      activeIcon: Icons.account_balance_rounded,
                      label: 'Loans',
                      currentIndex: currentIndex,
                      primary: primary,
                      isDark: isDark,
                      onTap: onTap),
                  _NavItem(
                      index: 2,
                      icon: Icons.account_balance_wallet_outlined,
                      activeIcon: Icons.account_balance_wallet_rounded,
                      label: 'Savings',
                      currentIndex: currentIndex,
                      primary: primary,
                      isDark: isDark,
                      onTap: onTap),
                  _NavItem(
                      index: 3,
                      icon: Icons.manage_accounts_outlined,
                      activeIcon: Icons.manage_accounts_rounded,
                      label: 'Users',
                      currentIndex: currentIndex,
                      primary: primary,
                      isDark: isDark,
                      onTap: onTap),
                  _NavItem(
                      index: 4,
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings_rounded,
                      label: 'Settings',
                      currentIndex: currentIndex,
                      primary: primary,
                      isDark: isDark,
                      onTap: onTap),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int currentIndex;
  final Color primary;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.currentIndex,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    final inactiveColor = isDark
        ? Colors.white.withOpacity(0.35)
        : Colors.black.withOpacity(0.28);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withOpacity(isDark ? 0.15 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.1 : 1.0,
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? primary : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primary : inactiveColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
