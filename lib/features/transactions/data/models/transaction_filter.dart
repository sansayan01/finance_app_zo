import '../../../../core/constants/enums.dart';

class TransactionFilter {
  final String searchQuery;
  final TransactionType? type;
  final List<PaymentMode> paymentModes;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? amountMin;
  final double? amountMax;
  final String sortBy;

  const TransactionFilter({
    this.searchQuery = '',
    this.type,
    this.paymentModes = const [],
    this.dateFrom,
    this.dateTo,
    this.amountMin,
    this.amountMax,
    this.sortBy = 'date_desc',
  });

  static const empty = TransactionFilter();

  int get activeFilterCount {
    int count = 0;
    if (searchQuery.isNotEmpty) count++;
    if (type != null) count++;
    if (dateFrom != null || dateTo != null) count++;
    if (amountMin != null || amountMax != null) count++;
    if (paymentModes.isNotEmpty) count++;
    if (sortBy != 'date_desc') count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

  TransactionFilter copyWith({
    String? searchQuery,
    bool clearSearchQuery = false,
    TransactionType? type,
    bool clearType = false,
    List<PaymentMode>? paymentModes,
    bool clearPaymentModes = false,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
    double? amountMin,
    bool clearAmountMin = false,
    double? amountMax,
    bool clearAmountMax = false,
    String? sortBy,
  }) {
    return TransactionFilter(
      searchQuery:
          clearSearchQuery ? '' : (searchQuery ?? this.searchQuery),
      type: clearType ? null : (type ?? this.type),
      paymentModes:
          clearPaymentModes ? const [] : (paymentModes ?? this.paymentModes),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      amountMin: clearAmountMin ? null : (amountMin ?? this.amountMin),
      amountMax: clearAmountMax ? null : (amountMax ?? this.amountMax),
      sortBy: sortBy ?? this.sortBy,
    );
  }

  TransactionFilter clearAll() => const TransactionFilter();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionFilter &&
          runtimeType == other.runtimeType &&
          searchQuery == other.searchQuery &&
          type == other.type &&
          paymentModes == other.paymentModes &&
          dateFrom == other.dateFrom &&
          dateTo == other.dateTo &&
          amountMin == other.amountMin &&
          amountMax == other.amountMax &&
          sortBy == other.sortBy;

  @override
  int get hashCode => Object.hash(
        searchQuery,
        type,
        paymentModes,
        dateFrom,
        dateTo,
        amountMin,
        amountMax,
        sortBy,
      );

  @override
  String toString() =>
      'TransactionFilter(query=$searchQuery, type=$type, '
      'paymentModes=$paymentModes, date=$dateFrom..$dateTo, '
      'amount=$amountMin..$amountMax, sort=$sortBy, '
      'active=$activeFilterCount)';
}
