import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Returns the currency symbol (e.g. '₹') from the formatter.
  static String get currencySymbol => _currencyFormat.currencySymbol;

  static final _percentFormat = NumberFormat.percentPattern();

  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _shortDateFormat = DateFormat('dd/MM/yyyy');
  static final _timeFormat = DateFormat('hh:mm a');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatPercent(double value) {
    return _percentFormat.format(value);
  }

  static String formatDate(DateTime date) {
    return _dateFormat.format(date.toLocal());
  }

  static String formatShortDate(DateTime date) {
    return _shortDateFormat.format(date.toLocal());
  }

  static String formatTime(DateTime time) {
    return _timeFormat.format(time.toLocal());
  }

  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime.toLocal());
  }

  static String formatPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 10) {
      return '+91 $cleaned';
    }
    return phone;
  }

  static String formatLoanId(String id) {
    return 'LF${id.substring(0, 8).toUpperCase()}';
  }

  static String formatMemberId(String id) {
    return 'MB${id.substring(0, 8).toUpperCase()}';
  }

  static String formatDaysRemaining(int days) {
    if (days <= 0) return 'Overdue';
    if (days == 1) return '1 day left';
    if (days < 7) return '$days days left';
    if (days < 30) return '${(days / 7).floor()} weeks left';
    return '${(days / 30).floor()} months left';
  }

  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatDate(dateTime);
  }

  /// Parse an ISO 8601 date string (from Supabase) and return a formatted date.
  /// Returns '-' if the string is null or cannot be parsed.
  static String parseIsoDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final date = DateTime.parse(isoString);
      return formatDate(date);
    } catch (_) {
      return '-';
    }
  }

  /// Parse an ISO 8601 date string and return a short formatted date.
  static String parseIsoDateShort(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final date = DateTime.parse(isoString);
      return formatShortDate(date);
    } catch (_) {
      return '-';
    }
  }

  static DateTime convertToIST(DateTime dateTime) {
    return dateTime.toLocal();
  }

  static String nowIST() {
    final now = DateTime.now();
    final ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
    return ist.toIso8601String().replaceFirst('Z', '+05:30');
  }
}
