import '../../../../core/constants/enums.dart';
import '../../../loans/presentation/widgets/statement_options_sheet.dart';

enum TransactionPeriod {
  today,
  thisWeek,
  thisMonth,
  last30Days,
  allFiltered,
  custom,
}

class TransactionExportOptions {
  final StatementFormat format;
  final TransactionPeriod period;
  final DateTime? customStart;
  final DateTime? customEnd;
  final bool includeSummary;
  final List<TransactionType> typeFilter;
  final List<PaymentMode> paymentModes;
  final double? amountMin;
  final double? amountMax;
  final String searchQuery;
  final String sortBy;

  const TransactionExportOptions({
    required this.format,
    required this.period,
    this.customStart,
    this.customEnd,
    this.includeSummary = true,
    this.typeFilter = const [],
    this.paymentModes = const [],
    this.amountMin,
    this.amountMax,
    this.searchQuery = '',
    this.sortBy = 'date_desc',
  });

  int get activeFilterCount {
    int count = 0;
    if (typeFilter.isNotEmpty) count++;
    if (paymentModes.isNotEmpty) count++;
    if (amountMin != null || amountMax != null) count++;
    if (searchQuery.isNotEmpty) count++;
    if (sortBy != 'date_desc') count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

  TransactionExportOptions copyWith({
    StatementFormat? format,
    TransactionPeriod? period,
    DateTime? customStart,
    bool clearCustomStart = false,
    DateTime? customEnd,
    bool clearCustomEnd = false,
    bool? includeSummary,
    List<TransactionType>? typeFilter,
    bool clearTypeFilter = false,
    List<PaymentMode>? paymentModes,
    bool clearPaymentModes = false,
    double? amountMin,
    bool clearAmountMin = false,
    double? amountMax,
    bool clearAmountMax = false,
    String? searchQuery,
    bool clearSearchQuery = false,
    String? sortBy,
  }) {
    return TransactionExportOptions(
      format: format ?? this.format,
      period: period ?? this.period,
      customStart: clearCustomStart ? null : (customStart ?? this.customStart),
      customEnd: clearCustomEnd ? null : (customEnd ?? this.customEnd),
      includeSummary: includeSummary ?? this.includeSummary,
      typeFilter: clearTypeFilter ? const [] : (typeFilter ?? this.typeFilter),
      paymentModes: clearPaymentModes ? const [] : (paymentModes ?? this.paymentModes),
      amountMin: clearAmountMin ? null : (amountMin ?? this.amountMin),
      amountMax: clearAmountMax ? null : (amountMax ?? this.amountMax),
      searchQuery: clearSearchQuery ? '' : (searchQuery ?? this.searchQuery),
      sortBy: sortBy ?? this.sortBy,
    );
  }

  DateTime? get resolvedStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case TransactionPeriod.today:
        return today;
      case TransactionPeriod.thisWeek:
        return today.subtract(Duration(days: today.weekday - 1));
      case TransactionPeriod.thisMonth:
        return DateTime(now.year, now.month, 1);
      case TransactionPeriod.last30Days:
        return today.subtract(const Duration(days: 29));
      case TransactionPeriod.allFiltered:
        return null;
      case TransactionPeriod.custom:
        return customStart;
    }
  }

  DateTime? get resolvedEnd {
    if (period == TransactionPeriod.allFiltered) return null;
    if (period == TransactionPeriod.custom) return customEnd;
    return DateTime.now();
  }
}
