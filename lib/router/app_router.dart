import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Setup Wizard
import '../features/setup/presentation/pages/setup_wizard_page.dart';

// Org / Setup completion
import '../core/providers/org_provider.dart';

// Branches
import '../features/branches/presentation/pages/branch_management_page.dart';

// Super Admin (Admin pages still in use)
import '../features/admin/presentation/pages/admin_org_detail_page.dart';
import '../features/admin/presentation/pages/admin_org_settings_page.dart';

// Auth
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/auth/presentation/pages/verify_email_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/data/models/user_model.dart';

// Admin Portal
import '../features/home/presentation/pages/home_page.dart';
import '../features/loans/presentation/pages/loans_page.dart';
import '../features/savings/presentation/pages/savings_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/settings/presentation/pages/profile_page.dart';
import '../features/settings/presentation/pages/activity_logs_page.dart';
import '../features/settings/presentation/pages/app_update_page.dart';
import '../core/widgets/hud_navigation.dart';
import '../features/loans/presentation/pages/loan_detail_page.dart';
import '../features/loans/presentation/pages/new_loan_page.dart';
import '../features/loans/presentation/pages/edit_loan_page.dart';
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
import '../features/staff/presentation/pages/staff_settings_page.dart';
import '../features/staff/presentation/pages/staff_targets_page.dart';
import '../features/staff/presentation/pages/staff_map_page.dart';
import '../features/staff/presentation/pages/analytics_dashboard.dart';
import '../features/staff/presentation/providers/sync_status_provider.dart';
import '../core/services/haptic_service.dart';

// Super Admin Portal
import '../features/super_admin/presentation/widgets/super_admin_shell.dart';
import '../features/super_admin/presentation/pages/super_admin_dashboard.dart';
import '../features/super_admin/presentation/pages/organizations_management_page.dart';
import '../features/super_admin/presentation/pages/users_management_page.dart';
import '../features/super_admin/presentation/pages/audit_logs_page.dart';
import '../features/super_admin/presentation/pages/support_tickets_page.dart';
import '../features/super_admin/presentation/pages/feature_flags_page.dart';
import '../features/super_admin/presentation/pages/announcements_page.dart';
import '../features/super_admin/presentation/pages/maintenance_page.dart';
import '../features/super_admin/presentation/pages/platform_analytics_page.dart';
import '../features/super_admin/presentation/pages/platform_settings_page.dart';
import '../features/super_admin/presentation/pages/platform_map_page.dart';
import '../features/super_admin/presentation/pages/security_scorecard_page.dart';
import '../features/super_admin/presentation/pages/nps_survey_page.dart';
import '../features/super_admin/presentation/pages/notification_center_page.dart';
import '../features/super_admin/presentation/pages/background_jobs_page.dart';
import '../features/super_admin/presentation/pages/onboarding_management_page.dart';
import '../features/super_admin/presentation/pages/report_center_page.dart';
import '../features/super_admin/presentation/pages/platform_health_page.dart';
import '../features/super_admin/presentation/pages/system_controls_page.dart';
import '../features/super_admin/presentation/pages/feature_adoption_page.dart';
import '../features/super_admin/presentation/pages/revenue_reconciliation_page.dart';
import '../features/super_admin/presentation/pages/executive_summary_page.dart';
import '../features/billing/presentation/pages/billing_page.dart';
import '../features/billing/presentation/pages/invoices_page.dart';
import '../features/billing/presentation/pages/usage_limits_page.dart';

// Branch Manager Portal - NEW
// import '../features/branch_manager/presentation/pages/branch_manager_shell.dart';
// import '../features/branch_manager/presentation/pages/branch_manager_dashboard.dart';
// import '../features/branch_manager/presentation/pages/staff_management_page.dart';
// import '../features/branch_manager/presentation/pages/branch_collections_page.dart';
// import '../features/branch_manager/presentation/pages/pending_approvals_page.dart';
// import '../features/branch_manager/presentation/pages/branch_cash_page.dart';

// =====================================================
// AUTH REDIRECT LISTENER
// =====================================================
class AuthRedirectListener extends ChangeNotifier {
  final Ref ref;

  AuthRedirectListener(this.ref) {
    // Listen to Auth state changes
    ref.listen<AuthState>(authProvider, (previous, next) {
      notifyListeners();
    });

    // Listen to Setup completion status changes
    ref.listen<AsyncValue<bool>>(setupCompleteProvider, (previous, next) {
      if (next.hasValue) {
        notifyListeners();
      }
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
      final authState = ref.read(authProvider);
      final authStatus = authState.status;
      final isAuthenticated = authStatus == AuthStatus.authenticated;
      final isEmailVerification = authStatus == AuthStatus.emailVerification;
      final isAuthPath = state.matchedLocation.startsWith('/auth');
      final isVerifyPath = state.matchedLocation == '/auth/verify-email';

      if (!isAuthenticated && !isAuthPath && !isEmailVerification) {
        return '/auth';
      }

      if (isEmailVerification && !isVerifyPath) {
        return '/auth/verify-email';
      }

      if (isAuthenticated) {
        final user = ref.read(currentUserProvider);
        final role = user?.role;
        final isSetupPath = state.matchedLocation == '/setup';
        final isAdminPath = state.matchedLocation == '/' || state.matchedLocation.startsWith('/loans') || state.matchedLocation.startsWith('/savings') || state.matchedLocation.startsWith('/users') || state.matchedLocation.startsWith('/settings') || state.matchedLocation.startsWith('/analytics') || state.matchedLocation.startsWith('/transactions') || state.matchedLocation.startsWith('/search') || state.matchedLocation.startsWith('/notifications') || state.matchedLocation.startsWith('/members') || state.matchedLocation.startsWith('/branches') || state.matchedLocation.startsWith('/super-admin');
        final isStaffPath = state.matchedLocation.startsWith('/staff');

        // Force setup for executive admins if setup is not complete
        if (role == UserRole.executiveAdmin) {
          final setupStatus = ref.read(setupCompleteProvider).valueOrNull ?? false;
          if (!setupStatus && !isSetupPath) {
            return '/setup';
          }
          if (setupStatus && isSetupPath) {
            return '/';
          }
        }

        // After login, route to correct portal based on role
        if (isAuthPath) {
          switch (role) {
            case UserRole.superAdmin:
              return '/super-admin';
            case UserRole.executiveAdmin:
              return '/';
            case UserRole.manager:
            case UserRole.collectionAgent:
              return '/staff';
            case UserRole.customer:
              return '/';
            default:
              return '/';
          }
        }

        // Staff role trying to access admin pages → redirect to staff
        if ((role == UserRole.manager || role == UserRole.collectionAgent) && isAdminPath) {
          return '/staff';
        }

        // Admin role trying to access staff pages → redirect to admin
        // Exception: executiveAdmin can access /staff/collection for payment recording
        if (role == UserRole.executiveAdmin && isStaffPath) {
          final isCollectionRoute = state.matchedLocation.startsWith('/staff/collection');
          if (!isCollectionRoute) {
            return '/';
          }
        }

        return null;
      }

      return null;
    },
    routes: [
      // Auth Shell
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthShell(),
        routes: [
          GoRoute(
            path: 'verify-email',
            builder: (context, state) => const VerifyEmailPage(),
          ),
        ],
      ),

      // Setup Wizard (for new organizations)
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupWizardPage(),
      ),

      // Super Admin Panel
      ShellRoute(
        builder: (context, state, child) {
          final user = ref.read(currentUserProvider);
          if (user?.role != UserRole.superAdmin) {
            return const Scaffold(body: Center(child: Text('Access denied')));
          }
          return SuperAdminShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/super-admin',
            builder: (context, state) => const SuperAdminDashboard(),
          ),
          GoRoute(
            path: '/super-admin/organizations',
            builder: (context, state) => const OrganizationsManagementPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return AdminOrgDetailPage(orgId: id);
                },
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const AdminOrgSettingsPage(),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/super-admin/users',
            builder: (context, state) => const UsersManagementPage(),
          ),
          GoRoute(
            path: '/super-admin/support',
            builder: (context, state) => const SupportTicketsPage(),
          ),
          GoRoute(
            path: '/super-admin/billing',
            builder: (context, state) => const BillingPage(),
            routes: [
              GoRoute(
                path: 'invoices',
                builder: (context, state) => const InvoicesPage(),
              ),
              GoRoute(
                path: 'usage-limits',
                builder: (context, state) => const UsageLimitsPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/super-admin/audit-logs',
            builder: (context, state) => const AuditLogsPage(),
          ),
          GoRoute(
            path: '/super-admin/feature-flags',
            builder: (context, state) => const FeatureFlagsPage(),
          ),
          GoRoute(
            path: '/super-admin/announcements',
            builder: (context, state) => const AnnouncementsPage(),
          ),
          GoRoute(
            path: '/super-admin/maintenance',
            builder: (context, state) => const MaintenancePage(),
          ),
          GoRoute(
            path: '/super-admin/settings',
            builder: (context, state) => const PlatformSettingsPage(),
          ),
          GoRoute(
            path: '/super-admin/analytics',
            builder: (context, state) => const PlatformAnalyticsPage(),
          ),
          GoRoute(
            path: '/super-admin/map',
            builder: (context, state) => const PlatformMapPage(),
          ),
          GoRoute(
            path: '/super-admin/security',
            builder: (context, state) => const SecurityScorecardPage(),
          ),
          GoRoute(
            path: '/super-admin/nps',
            builder: (context, state) => const NPSSurveyPage(),
          ),
          GoRoute(
            path: '/super-admin/notifications',
            builder: (context, state) => const NotificationCenterPage(),
          ),
          GoRoute(
            path: '/super-admin/jobs',
            builder: (context, state) => const BackgroundJobsPage(),
          ),
          GoRoute(
            path: '/super-admin/onboarding',
            builder: (context, state) => const OnboardingManagementPage(),
          ),
          GoRoute(
            path: '/super-admin/reports',
            builder: (context, state) => const ReportCenterPage(),
          ),
          GoRoute(
            path: '/super-admin/health',
            builder: (context, state) => const PlatformHealthPage(),
          ),
          GoRoute(
            path: '/super-admin/controls',
            builder: (context, state) => const SystemControlsPage(),
          ),
          GoRoute(
            path: '/super-admin/adoption',
            builder: (context, state) => const FeatureAdoptionPage(),
          ),
          GoRoute(
            path: '/super-admin/reconciliation',
            builder: (context, state) => const RevenueReconciliationPage(),
          ),
          GoRoute(
            path: '/super-admin/executive-summary',
            builder: (context, state) => const ExecutiveSummaryPage(),
          ),
        ],
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
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return EditLoanPage(loanId: id);
                },
              ),
            ],
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
              GoRoute(
                path: 'app-update',
                builder: (context, state) => const AppUpdatePage(),
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
          GoRoute(
            path: '/branches',
            builder: (context, state) => const BranchManagementPage(),
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
              final loanData = state.extra as Map<String, dynamic>?;
              return CollectionFormPage(
                loanId: loanId,
                loanData: loanData,
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
            builder: (context, state) => const VisitCheckInPage(),
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
            path: '/staff/settings',
            builder: (context, state) => const StaffSettingsPage(),
          ),
          GoRoute(
            path: '/staff/targets',
            builder: (context, state) => const StaffTargetsPage(),
          ),
          GoRoute(
            path: '/staff/map',
            builder: (context, state) => const StaffMapPage(),
          ),
          GoRoute(
            path: '/staff/analytics',
            builder: (context, state) => const AnalyticsDashboard(),
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

    // Redirect super admin to super admin panel
    if (user?.role == UserRole.superAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/super-admin');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Redirect staff to their dashboard
    if (user?.role == UserRole.collectionAgent || user?.role == UserRole.manager) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/staff');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Default dashboard
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
        location.startsWith('/staff/collection')) {
      return 1;
    }
    if (location.startsWith('/staff/customers')) return 2;
    if (location.startsWith('/staff/history')) return 3;
    if (location.startsWith('/staff/settings')) return 4;
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
        context.go('/staff/settings');
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
      minimum: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E2A).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
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
                badge: pendingCount > 0 ? pendingCount.toString() : null,
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
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'Settings',
                currentIndex: currentIndex,
                primary: primary,
                isDark: isDark,
                onTap: onTap,
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
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: () {
        HapticService.selection();
        onTap(index);
      },
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
                    ? primary.withValues(alpha: isDark ? 0.2 : 0.1)
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
      minimum: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3E3E4A).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.5),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
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
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.28);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.15 : 0.1)
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
