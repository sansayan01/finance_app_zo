import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Handles navigation when a push notification is tapped.
///
/// Parses the notification data payload and navigates to the appropriate screen.
class NotificationNavigationHandler {
  GoRouter? _router;

  /// Set the GoRouter instance (call after app initialization).
  void setRouter(GoRouter router) {
    _router = router;
  }

  /// Handle notification data payload and navigate.
  void handleNotificationData(Map<String, dynamic> data) {
    if (_router == null) {
      debugPrint('⚠️ Navigation handler: GoRouter not set');
      return;
    }

    final type = data['type'] as String?;
    final id = data['id'] as String?;

    debugPrint('🔔 Navigating for notification type: $type, id: $id');

    // If the sender specified a target portal, route within it. This prevents
    // staff-targeted notifications from landing on customer routes (and vice
    // versa). Falls back to customer-scoped routing when omitted.
    final target = data['target'] as String?;
    if (target == 'staff') {
      _navigateStaff(type, id);
      return;
    }

    switch (type) {
      case 'emi_reminder':
      case 'payment_due':
        _navigateToLoanDetails(data);
        break;
      case 'payment_received':
        _navigateToPaymentHistory(data);
        break;
      case 'loan_approved':
        _navigateToLoanDetails(data);
        break;
      case 'savings_update':
      case 'goal_milestone':
        _navigateToSavings(data);
        break;
      case 'collection_visit':
        _navigateToVisitCheckin(data);
        break;
      case 'target':
      case 'overdue':
        _navigateToStaffDashboard(data);
        break;
      case 'system':
      case 'alert':
      case 'reminder':
        _navigateToNotifications();
        break;
      default:
        _navigateToNotifications();
    }
  }

  void _navigateToLoanDetails(Map<String, dynamic> data) {
    final loanId = data['loan_id'] as String?;
    if (loanId != null) {
      _router?.push('/customer/loan/$loanId');
    } else {
      _router?.push('/customer/loans');
    }
  }

  void _navigateToPaymentHistory(Map<String, dynamic> data) {
    final loanId = data['loan_id'] as String?;
    if (loanId != null) {
      _router?.push('/customer/loan/$loanId/payments');
    } else {
      _router?.push('/customer/payments');
    }
  }

  void _navigateToSavings(Map<String, dynamic> data) {
    final savingsId = data['savings_plan_id'] as String?;
    if (savingsId != null) {
      _router?.push('/customer/savings/$savingsId');
    } else {
      _router?.push('/customer/savings');
    }
  }

  void _navigateToVisitCheckin(Map<String, dynamic> data) {
    _router?.push('/staff/visits');
  }

  void _navigateToStaffDashboard(Map<String, dynamic> data) {
    _router?.push('/staff');
  }

  void _navigateToNotifications() {
    _router?.push('/notifications');
  }

  /// Route staff-targeted notifications within the staff portal.
  void _navigateStaff(String? type, String? id) {
    switch (type) {
      case 'upi':
      case 'collection_visit':
        _router?.push('/staff/visits');
        break;
      case 'overdue':
      case 'target':
        _router?.push('/staff');
        break;
      default:
        _router?.push('/staff/notifications');
    }
  }
}
