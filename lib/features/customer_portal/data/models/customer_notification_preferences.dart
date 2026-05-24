import 'dart:convert';

/// Persisted notification preferences for the customer portal.
///
/// Stored as a JSON string in SharedPreferences under the key
/// `customer_notification_preferences`.
class CustomerNotificationPreferences {
  /// Master toggle for all push notifications.
  final bool pushEnabled;

  /// Master toggle for email notifications.
  final bool emailEnabled;

  /// Receive an EMI reminder 3 days before the due date.
  final bool emiReminder3Days;

  /// Receive an EMI reminder 1 day before the due date.
  final bool emiReminder1Day;

  /// Receive an EMI reminder on the due date itself.
  final bool emiReminderOnDue;

  /// Receive a confirmation when a payment is recorded.
  final bool paymentConfirmation;

  /// Receive alerts when a savings milestone (25/50/75/100%) is reached.
  final bool savingsMilestone;

  /// Receive system-level alerts (maintenance, announcements, etc.).
  final bool systemAlerts;

  /// SharedPreferences key.
  static const String storageKey = 'customer_notification_preferences';

  const CustomerNotificationPreferences({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.emiReminder3Days = true,
    this.emiReminder1Day = true,
    this.emiReminderOnDue = true,
    this.paymentConfirmation = true,
    this.savingsMilestone = true,
    this.systemAlerts = true,
  });

  /// Default preferences (all enabled).
  static const CustomerNotificationPreferences defaults =
      CustomerNotificationPreferences();

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  CustomerNotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? emiReminder3Days,
    bool? emiReminder1Day,
    bool? emiReminderOnDue,
    bool? paymentConfirmation,
    bool? savingsMilestone,
    bool? systemAlerts,
  }) {
    return CustomerNotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      emiReminder3Days: emiReminder3Days ?? this.emiReminder3Days,
      emiReminder1Day: emiReminder1Day ?? this.emiReminder1Day,
      emiReminderOnDue: emiReminderOnDue ?? this.emiReminderOnDue,
      paymentConfirmation: paymentConfirmation ?? this.paymentConfirmation,
      savingsMilestone: savingsMilestone ?? this.savingsMilestone,
      systemAlerts: systemAlerts ?? this.systemAlerts,
    );
  }

  // ---------------------------------------------------------------------------
  // JSON serialisation (for SharedPreferences)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'pushEnabled': pushEnabled,
        'emailEnabled': emailEnabled,
        'emiReminder3Days': emiReminder3Days,
        'emiReminder1Day': emiReminder1Day,
        'emiReminderOnDue': emiReminderOnDue,
        'paymentConfirmation': paymentConfirmation,
        'savingsMilestone': savingsMilestone,
        'systemAlerts': systemAlerts,
      };

  factory CustomerNotificationPreferences.fromJson(Map<String, dynamic> json) {
    return CustomerNotificationPreferences(
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      emailEnabled: json['emailEnabled'] as bool? ?? true,
      emiReminder3Days: json['emiReminder3Days'] as bool? ?? true,
      emiReminder1Day: json['emiReminder1Day'] as bool? ?? true,
      emiReminderOnDue: json['emiReminderOnDue'] as bool? ?? true,
      paymentConfirmation: json['paymentConfirmation'] as bool? ?? true,
      savingsMilestone: json['savingsMilestone'] as bool? ?? true,
      systemAlerts: json['systemAlerts'] as bool? ?? true,
    );
  }

  /// Serialise to a JSON string suitable for SharedPreferences.
  String toJsonString() => jsonEncode(toJson());

  /// Deserialise from a JSON string stored in SharedPreferences.
  static CustomerNotificationPreferences fromJsonString(String source) {
    try {
      return CustomerNotificationPreferences.fromJson(
          jsonDecode(source) as Map<String, dynamic>);
    } catch (_) {
      return defaults;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerNotificationPreferences &&
          pushEnabled == other.pushEnabled &&
          emailEnabled == other.emailEnabled &&
          emiReminder3Days == other.emiReminder3Days &&
          emiReminder1Day == other.emiReminder1Day &&
          emiReminderOnDue == other.emiReminderOnDue &&
          paymentConfirmation == other.paymentConfirmation &&
          savingsMilestone == other.savingsMilestone &&
          systemAlerts == other.systemAlerts;

  @override
  int get hashCode => Object.hash(
        pushEnabled,
        emailEnabled,
        emiReminder3Days,
        emiReminder1Day,
        emiReminderOnDue,
        paymentConfirmation,
        savingsMilestone,
        systemAlerts,
      );
}
