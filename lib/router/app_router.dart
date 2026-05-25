import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Chatbot
import '../features/chatbot/presentation/widgets/floating_chatbot.dart';

// Branches
import '../features/branches/presentation/pages/branch_management_page.dart';

// Payments
import '../features/payments/presentation/pages/today_payments_page.dart';

// Super Admin (Admin pages still in use)
import '../features/admin/presentation/pages/admin_org_detail_page.dart';
import '../features/admin/presentation/pages/admin_org_settings_page.dart';

// Auth
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/auth/presentation/pages/verify_email_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/data/models/user_model.dart';

// Setup
import '../features/setup/presentation/pages/setup_wizard_page.dart';
import '../features/setup/data/providers/setup_provider.dart';

// Admin Portal
import '../features/home/presentation/pages/home_page.dart';
import '../features/loans/presentation/pages/loans_page.dart';
import '../features/savings/presentation/pages/savings_page.dart';
import '../features/settings/presentation/pages/settings_page_v2.dart';
import '../features/settings/presentation/pages/organization_settings_page.dart';
import '../features/settings/presentation/pages/profile_page.dart';
import '../features/settings/presentation/pages/activity_logs_page.dart';
import '../features/settings/presentation/pages/app_update_page.dart';
import '../features/settings/presentation/pages/integrations_settings_page.dart';
import '../features/settings/presentation/pages/security_compliance_page.dart';
import '../core/widgets/hud_navigation.dart';
import '../core/constants/app_colors.dart';
import '../features/loans/presentation/pages/loan_detail_page.dart';
import '../features/loans/presentation/pages/new_loan_page.dart';
import '../features/loans/presentation/pages/edit_loan_page.dart';
import '../features/savings/presentation/pages/new_recurring_saving_page.dart';
import '../features/savings/presentation/pages/saving_detail_page.dart';
import '../features/savings/presentation/pages/edit_savings_vault_page.dart';
import '../features/users/presentation/pages/users_page.dart';
import '../features/users/presentation/pages/new_user_page.dart';
import '../features/users/presentation/pages/user_details_page.dart';
import '../features/users/presentation/pages/user_audit_page.dart';
import '../features/users/presentation/pages/org_chart_page.dart';
import '../features/users/presentation/pages/bulk_import_members_page.dart';
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
import '../core/constants/layout.dart';

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

// Branch Manager Portal
import '../features/branch_manager/presentation/pages/branch_manager_dashboard.dart';
import '../features/branch_manager/presentation/pages/staff_management_page.dart';
import '../features/branch_manager/presentation/pages/pending_approvals_page.dart';
import '../features/branch_manager/presentation/pages/branch_reports_page.dart';
import '../features/branch_manager/presentation/pages/manager_live_map_page.dart';
import '../features/branch_manager/presentation/pages/branch_members_page.dart';
import '../features/branch_manager/presentation/pages/branch_member_detail_page.dart';
import '../features/branch_manager/presentation/pages/branch_loans_page.dart';
import '../features/branch_manager/presentation/pages/branch_savings_page.dart';
import '../features/branch_manager/presentation/pages/branch_today_payments_page.dart';
import '../features/branch_manager/presentation/pages/branch_settings_page.dart';
import '../features/branch_manager/presentation/pages/branch_analytics_page.dart';

// Customer Portal
import '../features/customer_portal/presentation/pages/customer_home_page.dart';
import '../features/customer_portal/presentation/pages/customer_loans_page.dart';
import '../features/customer_portal/presentation/pages/customer_loan_detail_page.dart';
import '../features/customer_portal/presentation/pages/customer_emi_schedule_page.dart';
import '../features/customer_portal/presentation/pages/customer_savings_page.dart';
import '../features/customer_portal/presentation/pages/customer_savings_detail_page.dart';
import '../features/customer_portal/presentation/pages/customer_transactions_page.dart';
import '../features/customer_portal/presentation/pages/customer_notifications_page.dart';
import '../features/customer_portal/presentation/pages/customer_support_page.dart';
import '../features/customer_portal/presentation/pages/customer_profile_page.dart';
import '../features/customer_portal/presentation/pages/customer_account_settings_page.dart';
import '../features/customer_portal/presentation/pages/customer_feedback_page.dart';
import '../features/customer_portal/presentation/pages/customer_emi_calculator_page.dart';
import '../features/customer_portal/presentation/pages/customer_receipt_page.dart';

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
    initialLocation: '/splash',
    refreshListenable: authListener,
    redirect: (context, state) {
      // 1. Allow splash screen to display without redirection
      final isSplashPath = state.matchedLocation == '/splash';
      if (isSplashPath) {
        return null;
      }

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

        // Force setup wizard for executiveAdmin if setup not complete
        if (role == UserRole.executiveAdmin && !isSetupPath) {
          final setupAsync = ref.read(setupCompleteProvider);
          final isSetupComplete = setupAsync.valueOrNull ?? true;
          if (!isSetupComplete) {
            return '/setup';
          }
        }

        final isAdminPath = state.matchedLocation == '/' ||
            state.matchedLocation.startsWith('/loans') ||
            state.matchedLocation.startsWith('/savings') ||
            state.matchedLocation.startsWith('/users') ||
            state.matchedLocation.startsWith('/settings') ||
            state.matchedLocation.startsWith('/analytics') ||
            state.matchedLocation.startsWith('/transactions') ||
            state.matchedLocation.startsWith('/search') ||
            state.matchedLocation.startsWith('/notifications') ||
            state.matchedLocation.startsWith('/members') ||
            state.matchedLocation.startsWith('/branches') ||
            state.matchedLocation.startsWith('/super-admin');
        final isStaffPath = state.matchedLocation.startsWith('/staff');
        final isBranchPath = state.matchedLocation.startsWith('/branch');
        final isCustomerPath = state.matchedLocation.startsWith('/customer');

        // After login, route to correct portal based on role
        if (isAuthPath) {
          switch (role) {
            case UserRole.superAdmin:
              return '/super-admin';
            case UserRole.executiveAdmin:
              return '/';
            case UserRole.manager:
              return '/branch';
            case UserRole.collectionAgent:
              return '/staff';
            case UserRole.customer:
              return '/customer';
            default:
              return '/';
          }
        }

        // Staff role trying to access admin pages → redirect to staff
        if (role == UserRole.collectionAgent &&
            (isAdminPath || isBranchPath || isCustomerPath)) {
          return '/staff';
        }

        // Branch manager trying to access wrong pages → redirect to branch
        if (role == UserRole.manager &&
            (isAdminPath || isStaffPath || isCustomerPath)) {
          return '/branch';
        }

        // Customer trying to access wrong pages → redirect to customer
        if (role == UserRole.customer &&
            (isAdminPath || isStaffPath || isBranchPath)) {
          return '/customer';
        }

        // Admin role trying to access staff pages → redirect to admin
        // Exception: executiveAdmin can access /staff/collection for payment recording
        if (role == UserRole.executiveAdmin &&
            (isStaffPath || isBranchPath || isCustomerPath)) {
          final isCollectionRoute =
              state.matchedLocation.startsWith('/staff/collection');
          if (!isCollectionRoute) {
            return '/';
          }
        }

        return null;
      }

      return null;
    },
    routes: [
      // Splash Screen (Initial Brand Animation)
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),

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
            path: '/super-admin/app-update',
            builder: (context, state) => const AppUpdatePage(),
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
            path: '/payments',
            builder: (context, state) => const TodayPaymentsPage(),
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
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return EditSavingsVaultPage(savingId: id);
                },
              ),
            ],
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
            path: '/users/import',
            builder: (context, state) => const BulkImportMembersPage(),
          ),
          GoRoute(
            path: '/users/org-chart',
            builder: (context, state) => const OrgChartPage(),
          ),
          GoRoute(
            path: '/users/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return UserDetailsPage(userId: id);
            },
            routes: [
              GoRoute(
                path: 'audit',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return UserAuditPage(userId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPageV2(),
            routes: [
              GoRoute(
                path: 'profile',
                builder: (context, state) => const ProfilePage(),
              ),
              GoRoute(
                path: 'organization',
                builder: (context, state) => const OrganizationSettingsPage(),
              ),
              GoRoute(
                path: 'branding',
                builder: (context, state) => const OrganizationSettingsPage(),
              ),
              GoRoute(
                path: 'integrations',
                builder: (context, state) => const IntegrationsSettingsPage(),
              ),
              GoRoute(
                path: 'security',
                builder: (context, state) => const SecurityCompliancePage(),
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
          GoRoute(
            path: '/branches',
            builder: (context, state) => const BranchManagementPage(),
          ),
          GoRoute(
            path: '/live-map',
            builder: (context, state) => const ManagerLiveMapPage(),
          ),
        ],
      ),

      // Branch Manager Shell
      ShellRoute(
        builder: (context, state, child) {
          final user = ref.read(currentUserProvider);
          if (user?.role != UserRole.manager) {
            return const Scaffold(body: Center(child: Text('Access denied')));
          }
          return BranchManagerShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/branch',
            builder: (context, state) => const BranchManagerDashboard(),
          ),
          GoRoute(
            path: '/branch/staff',
            builder: (context, state) => const StaffManagementPage(),
          ),
          GoRoute(
            path: '/branch/approvals',
            builder: (context, state) => const PendingApprovalsPage(),
          ),
          GoRoute(
            path: '/branch/reports',
            builder: (context, state) => const BranchReportsPage(),
          ),
          GoRoute(
            path: '/branch/map',
            builder: (context, state) => const ManagerLiveMapPage(),
          ),
          GoRoute(
            path: '/branch/loans',
            builder: (context, state) => const BranchLoansPage(),
          ),
          GoRoute(
            path: '/branch/loans/new',
            builder: (context, state) => const NewLoanPage(),
          ),
          GoRoute(
            path: '/branch/loans/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return LoanDetailPage(loanId: id);
            },
          ),
          GoRoute(
            path: '/branch/savings',
            builder: (context, state) => const BranchSavingsPage(),
          ),
          GoRoute(
            path: '/branch/savings/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return SavingDetailPage(savingId: id);
            },
          ),
          GoRoute(
            path: '/branch/members',
            builder: (context, state) => const BranchMembersPage(),
          ),
          GoRoute(
            path: '/branch/members/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return BranchMemberDetailPage(memberId: id);
            },
          ),
          GoRoute(
            path: '/branch/payments',
            builder: (context, state) => const BranchTodayPaymentsPage(),
          ),
          GoRoute(
            path: '/branch/analytics',
            builder: (context, state) => const BranchAnalyticsPage(),
          ),
          GoRoute(
            path: '/branch/settings',
            builder: (context, state) => const BranchSettingsPage(),
          ),
          GoRoute(
            path: '/branch/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),

      // Customer Portal Shell
      ShellRoute(
        builder: (context, state, child) {
          final user = ref.read(currentUserProvider);
          if (user?.role != UserRole.customer) {
            return const Scaffold(body: Center(child: Text('Access denied')));
          }
          return CustomerShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/customer',
            builder: (context, state) => const CustomerHomePage(),
          ),
          GoRoute(
            path: '/customer/loans',
            builder: (context, state) => const CustomerLoansPage(),
          ),
          GoRoute(
            path: '/customer/loans/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CustomerLoanDetailPage(loanId: id);
            },
          ),
          GoRoute(
            path: '/customer/loans/:id/schedule',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CustomerEmiSchedulePage(loanId: id);
            },
          ),
          GoRoute(
            path: '/customer/savings',
            builder: (context, state) => const CustomerSavingsPage(),
          ),
          GoRoute(
            path: '/customer/savings/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CustomerSavingsDetailPage(savingsId: id);
            },
          ),
          GoRoute(
            path: '/customer/transactions',
            builder: (context, state) => const CustomerTransactionsPage(),
          ),
          GoRoute(
            path: '/customer/notifications',
            builder: (context, state) => const CustomerNotificationsPage(),
          ),
          GoRoute(
            path: '/customer/support',
            builder: (context, state) => const CustomerSupportPage(),
          ),
          GoRoute(
            path: '/customer/profile',
            builder: (context, state) => const CustomerProfilePage(),
          ),
          GoRoute(
            path: '/customer/feedback',
            builder: (context, state) => const CustomerFeedbackPage(),
          ),
          GoRoute(
            path: '/customer/emi-calculator',
            builder: (context, state) => const CustomerEmiCalculatorPage(),
          ),
          GoRoute(
            path: '/customer/account-settings',
            builder: (context, state) => const CustomerAccountSettingsPage(),
          ),
          GoRoute(
            path: '/customer/receipt',
            builder: (context, state) {
              final args = state.extra as Map<String, dynamic>;
              return CustomerReceiptPage(
                transactionId: args['transactionId'] as String,
                amount: args['amount'] as double,
                type: args['type'] as String,
                date: args['date'] as DateTime,
                memberName: args['memberName'] as String?,
                paymentMode: args['paymentMode'] as String?,
                referenceNumber: args['referenceNumber'] as String?,
                description: args['description'] as String?,
                status: (args['status'] as String?) ?? 'synced',
              );
            },
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

    // Redirect branch manager to their dashboard
    if (user?.role == UserRole.manager) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/branch');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Redirect staff to their dashboard
    if (user?.role == UserRole.collectionAgent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/staff');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Redirect customer to their portal
    if (user?.role == UserRole.customer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/customer');
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
class AdminShell extends ConsumerStatefulWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
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
          // Inject inflated MediaQuery so SafeArea(bottom: true) and any
          // widget that reads MediaQuery.padding.bottom inside the page
          // automatically clears the floating glass navbar. Only applied
          // when the bottom navbar is actually shown (mobile layout).
          useHudNav ? widget.child : _NavSafeArea(child: widget.child),
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
          // Draggable AI Chatbot overlay
          const FloatingChatbot(),
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
class StaffShell extends ConsumerStatefulWidget {
  final Widget child;

  const StaffShell({super.key, required this.child});

  @override
  ConsumerState<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends ConsumerState<StaffShell> {
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
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    // Get pending operations count
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingCount = syncStatus.pending;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: _NavSafeArea(child: widget.child),
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
// BRANCH MANAGER SHELL
// =====================================================
class BranchManagerShell extends ConsumerStatefulWidget {
  final Widget child;
  const BranchManagerShell({super.key, required this.child});

  @override
  ConsumerState<BranchManagerShell> createState() => _BranchManagerShellState();
}

class _BranchManagerShellState extends ConsumerState<BranchManagerShell> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/branch/loans')) return 1;
    if (location.startsWith('/branch/savings')) return 2;
    if (location.startsWith('/branch/members')) return 3;
    if (location.startsWith('/branch/settings')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/branch');
        break;
      case 1:
        context.go('/branch/loans');
        break;
      case 2:
        context.go('/branch/savings');
        break;
      case 3:
        context.go('/branch/members');
        break;
      case 4:
        context.go('/branch/settings');
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
          useHudNav ? widget.child : _NavSafeArea(child: widget.child),
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
                        label: 'Members',
                        icon: Icons.people_outline,
                        activeIcon: Icons.people_rounded),
                    HUDNavItem(
                        label: 'Settings',
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings_rounded),
                  ],
                ),
              ),
            ),
          const FloatingChatbot(),
        ],
      ),
      bottomNavigationBar: useHudNav
          ? null
          : _PremiumBottomBar(
              currentIndex: currentIndex,
              onTap: (index) => _onItemTapped(index, context),
              items: const [
                _NavData(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Home'),
                _NavData(Icons.account_balance_outlined, Icons.account_balance_rounded, 'Loans'),
                _NavData(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Savings'),
                _NavData(Icons.people_outline, Icons.people_rounded, 'Members'),
                _NavData(Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
              ],
            ),
    );
  }
}

// =====================================================
// CUSTOMER SHELL
// =====================================================
class CustomerShell extends ConsumerStatefulWidget {
  final Widget child;
  const CustomerShell({super.key, required this.child});

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/customer/loans')) return 1;
    if (location.startsWith('/customer/savings')) return 2;
    if (location.startsWith('/customer/transactions') ||
        location.startsWith('/customer/notifications') ||
        location.startsWith('/customer/support')) {
      return 3;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/customer');
        break;
      case 1:
        context.go('/customer/loans');
        break;
      case 2:
        context.go('/customer/savings');
        break;
      case 3:
        _showMoreMenu(context);
        break;
    }
  }

  void _showMoreMenu(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2030) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMoreItem(context, Icons.receipt_long_rounded,
                            'Transactions', 'View all payment history', isDark, () {
                          Navigator.pop(context);
                          context.go('/customer/transactions');
                        }),
                        _buildMoreItem(context, Icons.notifications_rounded,
                            'Notifications', 'Alerts and reminders', isDark, () {
                          Navigator.pop(context);
                          context.go('/customer/notifications');
                        }),
                        _buildMoreItem(context, Icons.support_agent_rounded,
                            'Support', 'Get help and create tickets', isDark, () {
                          Navigator.pop(context);
                          context.go('/customer/support');
                        }),
                        _buildMoreItem(context, Icons.calculate_rounded,
                            'EMI Calculator', 'Plan your loan repayment', isDark, () {
                          Navigator.pop(context);
                          context.go('/customer/emi-calculator');
                        }),
                        _buildMoreItem(context, Icons.rate_review_rounded,
                            'Feedback', 'Help us improve our service', isDark, () {
                          Navigator.pop(context);
                          context.go('/customer/feedback');
                        }),
                        _buildMoreItem(context, Icons.settings_rounded,
                            'Account Settings', 'Preferences and security', isDark, () {
                          Navigator.pop(context);
                          context.go('/customer/account-settings');
                        }),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Divider(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.08)),
                        ),
                        _buildMoreItem(context, Icons.logout_rounded, 'Logout',
                            'Sign out of your account', isDark, () async {
                          Navigator.pop(context);
                          await ref.read(authProvider.notifier).signOut();
                        }, isError: true),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreItem(BuildContext context, IconData icon, String title,
      String subtitle, bool isDark, VoidCallback onTap,
      {bool isError = false}) {
    final color = isError ? const Color(0xFFEF4444) : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isError
                              ? const Color(0xFFEF4444)
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: (isDark ? Colors.white : const Color(0xFF0F172A))
                              .withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.2),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: _NavSafeArea(child: widget.child),
      bottomNavigationBar: SafeArea(
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
                        onTap: (i) => _onItemTapped(i, context)),
                    _NavItem(
                        index: 1,
                        icon: Icons.account_balance_outlined,
                        activeIcon: Icons.account_balance_rounded,
                        label: 'Loans',
                        currentIndex: currentIndex,
                        primary: primary,
                        isDark: isDark,
                        onTap: (i) => _onItemTapped(i, context)),
                    _NavItem(
                        index: 2,
                        icon: Icons.account_balance_wallet_outlined,
                        activeIcon: Icons.account_balance_wallet_rounded,
                        label: 'Savings',
                        currentIndex: currentIndex,
                        primary: primary,
                        isDark: isDark,
                        onTap: (i) => _onItemTapped(i, context)),
                    _NavItem(
                        index: 3,
                        icon: Icons.more_horiz_outlined,
                        activeIcon: Icons.more_horiz_rounded,
                        label: 'More',
                        currentIndex: currentIndex,
                        primary: primary,
                        isDark: isDark,
                        onTap: (i) => _onItemTapped(i, context)),
                  ],
                ),
              ),
            ),
          ),
        ),
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
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
// =====================================================
// PREMIUM BOTTOM BAR (Admin)
// =====================================================
class _NavData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavData(this.icon, this.activeIcon, this.label);
}

class _PremiumBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavData>? items;

  const _PremiumBottomBar({required this.currentIndex, required this.onTap, this.items});

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
                children: (items ?? [
                  const _NavData(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Home'),
                  const _NavData(Icons.account_balance_outlined, Icons.account_balance_rounded, 'Loans'),
                  const _NavData(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Savings'),
                  const _NavData(Icons.manage_accounts_outlined, Icons.manage_accounts_rounded, 'Users'),
                  const _NavData(Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
                ]).asMap().entries.map((entry) => _NavItem(
                      index: entry.key,
                      icon: entry.value.icon,
                      activeIcon: entry.value.activeIcon,
                      label: entry.value.label,
                      currentIndex: currentIndex,
                      primary: primary,
                      isDark: isDark,
                      onTap: onTap)).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// _NavSafeArea
// Inflates MediaQuery so pages inside Admin/Staff shells reserve room
// for the floating glass bottom nav. Any widget that uses
// SafeArea(bottom: true) or reads MediaQuery.padding.bottom now sees
// (system inset + navbar height). Pages without those widgets can use
// kBottomNavSafeArea directly.
// =====================================================
class _NavSafeArea extends StatelessWidget {
  final Widget child;
  const _NavSafeArea({required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(
          bottom: mq.padding.bottom + kBottomNavSafeArea,
        ),
        viewPadding: mq.viewPadding.copyWith(
          bottom: mq.viewPadding.bottom + kBottomNavSafeArea,
        ),
      ),
      child: child,
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
