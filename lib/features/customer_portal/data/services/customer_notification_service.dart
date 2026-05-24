import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for creating, managing, and smart-generating customer notifications.
///
/// Works against the existing `customer_notifications` Supabase table and can
/// be extended to push via FCM when Firebase Messaging is added.
class CustomerNotificationService {
  final SupabaseClient _client;

  CustomerNotificationService(this._client);

  // ---------------------------------------------------------------------------
  // Notification types
  // ---------------------------------------------------------------------------

  static const String typePaymentDue = 'payment_due';
  static const String typeCollectionVisit = 'collection_visit';
  static const String typeLoanApproved = 'loan_approved';
  static const String typeSavingsUpdate = 'savings_update';
  static const String typePaymentReceived = 'payment_received';
  static const String typeEmiReminder = 'emi_reminder';
  static const String typeGoalMilestone = 'goal_milestone';
  static const String typeSystem = 'system';

  /// All recognised notification types.
  static const List<String> allTypes = [
    typePaymentDue,
    typeCollectionVisit,
    typeLoanApproved,
    typeSavingsUpdate,
    typePaymentReceived,
    typeEmiReminder,
    typeGoalMilestone,
    typeSystem,
  ];

  // ---------------------------------------------------------------------------
  // Core CRUD
  // ---------------------------------------------------------------------------

  /// Create a single notification row in `customer_notifications`.
  Future<void> createNotification({
    required String customerId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    await _client.from('customer_notifications').insert({
      'customer_id': customerId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': false,
      if (data != null) 'data': data,
    });
  }

  /// Batch-mark every unread notification for [customerId] as read.
  Future<void> markAllAsRead(String customerId) async {
    await _client.from('customer_notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('customer_id', customerId).eq('is_read', false);
  }

  /// Delete notifications older than [daysThreshold] (default 30 days).
  Future<void> cleanupOldNotifications(
    String customerId, {
    int daysThreshold = 30,
  }) async {
    final cutoff =
        DateTime.now().subtract(Duration(days: daysThreshold)).toIso8601String();
    await _client
        .from('customer_notifications')
        .delete()
        .eq('customer_id', customerId)
        .lt('created_at', cutoff);
  }

  // ---------------------------------------------------------------------------
  // Smart notification generation
  // ---------------------------------------------------------------------------

  /// Orchestrator that checks all data-driven notification sources for a
  /// customer in one call. Safe to invoke on every app launch -- duplicate
  /// notifications are suppressed via a look-back window.
  Future<void> generateSmartNotifications(
    String customerId,
    String orgId,
  ) async {
    await Future.wait([
      checkEmiReminders(customerId, orgId),
      checkSavingsMilestones(customerId, orgId),
      checkLoanApprovals(customerId, orgId),
      checkPaymentConfirmations(customerId, orgId),
    ]);
  }

  // ---------------------------------------------------------------------------
  // EMI reminders (3 days, 1 day, on due date)
  // ---------------------------------------------------------------------------

  /// Check for upcoming EMIs and fire reminders at 3-day, 1-day, and same-day
  /// windows. Duplicate suppression: a reminder of the same window for the
  /// same EMI is not created twice within 24 hours.
  Future<void> checkEmiReminders(String customerId, String orgId) async {
    try {
      // Fetch active loans for the customer.
      final loans = await _client
          .from('loans')
          .select('id, loan_number, emi_amount')
          .eq('customer_id', customerId)
          .eq('org_id', orgId)
          .eq('status', 'active');

      if (loans.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final loan in loans) {
        final loanId = loan['id'] as String;
        final loanNumber = loan['loan_number']?.toString() ?? loanId;
        final emiAmount = (loan['emi_amount'] ?? 0).toDouble();

        // Fetch next few unpaid EMIs for this loan.
        final schedules = await _client
            .from('emi_schedule')
            .select('id, emi_number, due_date, is_paid')
            .eq('loan_id', loanId)
            .eq('is_paid', false)
            .order('emi_number', ascending: true)
            .limit(5);

        if (schedules.isEmpty) continue;

        for (final schedule in schedules) {
          final dueDateRaw = schedule['due_date'];
          if (dueDateRaw == null) continue;

          final dueDate = DateTime.tryParse(dueDateRaw.toString());
          if (dueDate == null) continue;

          final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
          final daysUntilDue = dueDay.difference(today).inDays;

          String? windowLabel;
          if (daysUntilDue == 3) {
            windowLabel = '3_days';
          } else if (daysUntilDue == 1) {
            windowLabel = '1_day';
          } else if (daysUntilDue == 0) {
            windowLabel = 'today';
          }

          if (windowLabel == null) continue;

          // Duplicate suppression -- check if we already sent this window
          // reminder for this EMI in the last 24 hours.
          final recentCutoff =
              now.subtract(const Duration(hours: 24)).toIso8601String();
          final existing = await _client
              .from('customer_notifications')
              .select('id')
              .eq('customer_id', customerId)
              .eq('type', typeEmiReminder)
              .contains('data', {'emi_schedule_id': schedule['id']})
              .contains('data', {'window': windowLabel})
              .gte('created_at', recentCutoff)
              .limit(1);

          if (existing.isNotEmpty) continue;

          // Build the reminder.
          String title;
          String message;
          if (windowLabel == 'today') {
            title = 'EMI Due Today';
            message =
                'Your EMI of \$${emiAmount.toStringAsFixed(2)} for loan '
                '$loanNumber is due today. Please pay on time to avoid penalties.';
          } else if (windowLabel == '1_day') {
            title = 'EMI Due Tomorrow';
            message =
                'Your EMI of \$${emiAmount.toStringAsFixed(2)} for loan '
                '$loanNumber is due tomorrow.';
          } else {
            title = 'EMI Due in 3 Days';
            message =
                'Your EMI of \$${emiAmount.toStringAsFixed(2)} for loan '
                '$loanNumber is due in 3 days on '
                '${dueDay.month}/${dueDay.day}/${dueDay.year}.';
          }

          await createNotification(
            customerId: customerId,
            title: title,
            message: message,
            type: typeEmiReminder,
            data: {
              'loan_id': loanId,
              'emi_schedule_id': schedule['id'],
              'emi_number': schedule['emi_number'],
              'window': windowLabel,
              'amount': emiAmount,
            },
          );
        }
      }
    } catch (_) {
      // Silently swallow -- notifications are non-critical and should never
      // crash the app. Log in production.
    }
  }

  // ---------------------------------------------------------------------------
  // Savings milestones
  // ---------------------------------------------------------------------------

  /// Fire a notification when a savings plan crosses 25%, 50%, 75%, or 100% of
  /// its target. Duplicate suppression: same milestone for same plan is not
  // sent more than once.
  Future<void> checkSavingsMilestones(
    String customerId,
    String orgId,
  ) async {
    try {
      final savings = await _client
          .from('savings_plans')
          .select('id, plan_name, target_amount, current_amount, status')
          .eq('member_id', customerId)
          .eq('org_id', orgId)
          .eq('status', 'active');

      if (savings.isEmpty) return;

      const milestones = [25, 50, 75, 100];

      for (final plan in savings) {
        final targetAmount = (plan['target_amount'] ?? 0).toDouble();
        if (targetAmount <= 0) continue;

        final currentAmount = (plan['current_amount'] ?? 0).toDouble();
        final percentage = (currentAmount / targetAmount * 100).clamp(0, 100);
        final planName =
            plan['plan_name']?.toString() ?? 'Savings Account';

        for (final milestone in milestones) {
          if (percentage < milestone) continue;

          // Check if we already sent this milestone for this plan.
          final existing = await _client
              .from('customer_notifications')
              .select('id')
              .eq('customer_id', customerId)
              .eq('type', typeGoalMilestone)
              .contains('data', {'savings_plan_id': plan['id']})
              .contains('data', {'milestone': milestone})
              .limit(1);

          if (existing.isNotEmpty) continue;

          String title;
          String message;
          if (milestone == 100) {
            title = 'Goal Reached!';
            message =
                'Congratulations! Your "$planName" savings goal of '
                '\$${targetAmount.toStringAsFixed(2)} has been fully reached!';
          } else {
            title = '$milestone% Milestone Reached';
            message =
                'Your "$planName" savings has reached $milestone% of '
                '\$${targetAmount.toStringAsFixed(2)} target. Keep it up!';
          }

          await createNotification(
            customerId: customerId,
            title: title,
            message: message,
            type: typeGoalMilestone,
            data: {
              'savings_plan_id': plan['id'],
              'milestone': milestone,
              'current_amount': currentAmount,
              'target_amount': targetAmount,
            },
          );
        }
      }
    } catch (_) {
      // Non-critical.
    }
  }

  // ---------------------------------------------------------------------------
  // Loan approvals
  // ---------------------------------------------------------------------------

  /// Check for recently approved loans that do not yet have a notification.
  Future<void> checkLoanApprovals(
    String customerId,
    String orgId,
  ) async {
    try {
      // Fetch loans approved in the last 7 days.
      final cutoff =
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final loans = await _client
          .from('loans')
          .select('id, loan_number, amount, status, updated_at')
          .eq('customer_id', customerId)
          .eq('org_id', orgId)
          .eq('status', 'active')
          .gte('updated_at', cutoff);

      if (loans.isEmpty) return;

      for (final loan in loans) {
        final loanId = loan['id'] as String;

        // Suppress duplicate.
        final existing = await _client
            .from('customer_notifications')
            .select('id')
            .eq('customer_id', customerId)
            .eq('type', typeLoanApproved)
            .contains('data', {'loan_id': loanId})
            .limit(1);

        if (existing.isNotEmpty) continue;

        final loanNumber = loan['loan_number']?.toString() ?? loanId;
        final amount = (loan['amount'] ?? 0).toDouble();

        await createNotification(
          customerId: customerId,
          title: 'Loan Approved',
          message:
              'Your loan $loanNumber for \$${amount.toStringAsFixed(2)} has '
              'been approved and is now active.',
          type: typeLoanApproved,
          data: {'loan_id': loanId, 'amount': amount},
        );
      }
    } catch (_) {
      // Non-critical.
    }
  }

  // ---------------------------------------------------------------------------
  // Payment confirmations
  // ---------------------------------------------------------------------------

  /// Check for recent payments (collections) and confirm them via notification.
  Future<void> checkPaymentConfirmations(
    String customerId,
    String orgId,
  ) async {
    try {
      final cutoff =
          DateTime.now().subtract(const Duration(days: 3)).toIso8601String();

      // The `payments` table records collections against loans.
      final payments = await _client
          .from('payments')
          .select('id, loan_id, amount, payment_date, created_at')
          .eq('member_id', customerId)
          .eq('org_id', orgId)
          .gte('created_at', cutoff)
          .order('created_at', ascending: false)
          .limit(10);

      if (payments.isEmpty) return;

      for (final payment in payments) {
        final paymentId = payment['id'] as String;

        // Suppress duplicate.
        final existing = await _client
            .from('customer_notifications')
            .select('id')
            .eq('customer_id', customerId)
            .eq('type', typePaymentReceived)
            .contains('data', {'payment_id': paymentId})
            .limit(1);

        if (existing.isNotEmpty) continue;

        final amount = (payment['amount'] ?? 0).toDouble();
        final paymentDateRaw = payment['payment_date'];
        final paymentDate = paymentDateRaw != null
            ? DateTime.tryParse(paymentDateRaw.toString())
            : null;
        final formattedDate = paymentDate != null
            ? '${paymentDate.month}/${paymentDate.day}/${paymentDate.year}'
            : 'today';

        await createNotification(
          customerId: customerId,
          title: 'Payment Received',
          message:
              'We received your payment of \$${amount.toStringAsFixed(2)} on '
              '$formattedDate. Thank you!',
          type: typePaymentReceived,
          data: {
            'payment_id': paymentId,
            'amount': amount,
          },
        );
      }
    } catch (_) {
      // Non-critical.
    }
  }
}
