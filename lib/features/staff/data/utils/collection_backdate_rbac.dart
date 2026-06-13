import 'package:microflow_pro/core/constants/enums.dart';

/// RBAC enforcement for collection backdating.
class CollectionBackdateRbac {
  CollectionBackdateRbac._();

  /// Maximum days a collection can be backdated.
  static const int maxBackdateDays = 365;

  /// Roles allowed to backdate collections.
  /// customer/readonly roles are intentionally excluded.
  static bool canBackdate(UserRole role) {
    return role == UserRole.superAdmin ||
        role == UserRole.executiveAdmin ||
        role == UserRole.manager ||
        role == UserRole.collectionAgent;
  }

  /// True if the number of days back is within the allowed window.
  static bool isWithinBackdateLimit(int days) {
    return days >= 0 && days <= maxBackdateDays;
  }

  /// Compute how many days back from today a target date is.
  /// Returns 0 for today, positive for past dates.
  static int computeDaysBack(DateTime target) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final targetOnly = DateTime(target.year, target.month, target.day);
    return todayOnly.difference(targetOnly).inDays;
  }

  /// Validate a backdate request. Returns null if valid, error string if not.
  static String? validateBackdate({
    required DateTime selectedDate,
    required UserRole role,
    String? reason,
  }) {
    if (!canBackdate(role)) {
      return 'Your role does not permit backdating collections';
    }
    final days = computeDaysBack(selectedDate);
    if (days < 0) {
      return 'Cannot future-date collections';
    }
    if (days > maxBackdateDays) {
      return 'Cannot backdate more than $maxBackdateDays days';
    }
    if (days > 0 && (reason == null || reason.trim().isEmpty)) {
      return 'A reason is required when backdating';
    }
    return null;
  }
}
