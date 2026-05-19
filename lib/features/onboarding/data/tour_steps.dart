import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/enums.dart';
import '../presentation/widgets/tour_overlay.dart';

/// Returns the tour steps appropriate for the given user role.
List<TourStep> getTourSteps(UserRole? role) {
  switch (role) {
    case UserRole.executiveAdmin:
      return _executiveAdminSteps;
    case UserRole.manager:
      return _branchManagerSteps;
    case UserRole.collectionAgent:
      return _staffSteps;
    case UserRole.customer:
      return _customerSteps;
    default:
      return _executiveAdminSteps;
  }
}

const _executiveAdminSteps = [
  TourStep(
    title: 'Welcome to MicroFlow Pro',
    description:
        'Your complete micro-finance management platform. '
        'Let\'s take a quick look at what you can do here.',
    icon: Icons.rocket_launch_rounded,
    accentColor: AppColors.primary,
  ),
  TourStep(
    title: 'Dashboard Overview',
    description:
        'Your dashboard shows total outstanding, active members, '
        'today\'s collections, and PAR rate at a glance. '
        'Pull down to refresh anytime.',
    icon: Icons.dashboard_rounded,
    accentColor: AppColors.info,
  ),
  TourStep(
    title: 'Quick Actions',
    description:
        'Create new loans, savings plans, add users, manage branches, '
        'and view analytics — all from the quick action buttons on your dashboard.',
    icon: Icons.flash_on_rounded,
    accentColor: AppColors.warning,
  ),
  TourStep(
    title: 'User Hub',
    description:
        'Manage your entire team from the Users tab. Add branch managers, '
        'collection agents, and customers. Set passwords, assign branches, '
        'and track activity.',
    icon: Icons.people_rounded,
    accentColor: AppColors.success,
  ),
  TourStep(
    title: 'You\'re All Set!',
    description:
        'Start by creating a branch, then add a branch manager. '
        'You can always replay this tour from Settings. '
        'Happy managing!',
    icon: Icons.celebration_rounded,
    accentColor: AppColors.primary,
  ),
];

const _branchManagerSteps = [
  TourStep(
    title: 'Welcome, Branch Manager',
    description:
        'You have oversight of your branch — staff performance, '
        'collections, and approvals are all here.',
    icon: Icons.rocket_launch_rounded,
    accentColor: AppColors.primary,
  ),
  TourStep(
    title: 'Branch Dashboard',
    description:
        'See your branch stats: total collections today, '
        'staff on field, pending approvals, and overdue accounts.',
    icon: Icons.store_rounded,
    accentColor: AppColors.info,
  ),
  TourStep(
    title: 'Staff Management',
    description:
        'Monitor your collection agents, assign areas, '
        'and track their daily performance and GPS check-ins.',
    icon: Icons.badge_rounded,
    accentColor: AppColors.warning,
  ),
  TourStep(
    title: 'Approvals',
    description:
        'Review and approve loan applications, savings plans, '
        'and other requests from your branch.',
    icon: Icons.approval_rounded,
    accentColor: AppColors.success,
  ),
  TourStep(
    title: 'Ready to Go!',
    description:
        'Check your staff list and today\'s agenda to get started. '
        'Replay this tour anytime from Settings.',
    icon: Icons.celebration_rounded,
    accentColor: AppColors.primary,
  ),
];

const _staffSteps = [
  TourStep(
    title: 'Welcome, Agent',
    description:
        'MicroFlow Pro helps you manage your daily collections, '
        'track visits, and earn rewards.',
    icon: Icons.rocket_launch_rounded,
    accentColor: AppColors.primary,
  ),
  TourStep(
    title: 'Today\'s Agenda',
    description:
        'Your dashboard shows today\'s collection targets, '
        'pending visits, and your current streak.',
    icon: Icons.today_rounded,
    accentColor: AppColors.info,
  ),
  TourStep(
    title: 'Record Collections',
    description:
        'Tap to record payments with GPS tagging. '
        'Works offline too — collections sync automatically when you\'re back online.',
    icon: Icons.payments_rounded,
    accentColor: AppColors.success,
  ),
  TourStep(
    title: 'Earn Rewards',
    description:
        'Build streaks, unlock achievements, and climb the leaderboard. '
        'Consistent collections earn you bonus points!',
    icon: Icons.emoji_events_rounded,
    accentColor: AppColors.warning,
  ),
  TourStep(
    title: 'Let\'s Collect!',
    description:
        'Check your today\'s agenda and start your first collection. '
        'Replay this tour from Settings anytime.',
    icon: Icons.celebration_rounded,
    accentColor: AppColors.primary,
  ),
];

const _customerSteps = [
  TourStep(
    title: 'Welcome to MicroFlow',
    description:
        'Track your loans, payments, and savings all in one place.',
    icon: Icons.rocket_launch_rounded,
    accentColor: AppColors.primary,
  ),
  TourStep(
    title: 'Your Loans',
    description:
        'View your active loans, repayment schedule, '
        'and payment history at a glance.',
    icon: Icons.account_balance_rounded,
    accentColor: AppColors.info,
  ),
  TourStep(
    title: 'Savings',
    description:
        'Track your savings balance, maturity dates, '
        'and deposit history.',
    icon: Icons.savings_rounded,
    accentColor: AppColors.success,
  ),
  TourStep(
    title: 'You\'re Ready!',
    description:
        'Explore your dashboard to see your financial overview. '
        'Contact support anytime if you need help.',
    icon: Icons.celebration_rounded,
    accentColor: AppColors.primary,
  ),
];
