/// Immutable filter state for customer transaction search and filtering.
/// Tracks search query, type filter, date range, amount range, and sort order.
class CustomerTransactionFilter {
  final String? searchQuery;
  final String? typeFilter;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? amountMin;
  final double? amountMax;
  final String sortBy;

  const CustomerTransactionFilter({
    this.searchQuery,
    this.typeFilter,
    this.dateFrom,
    this.dateTo,
    this.amountMin,
    this.amountMax,
    this.sortBy = 'date_desc',
  });

  /// Empty / default filter with no active criteria.
  static const empty = CustomerTransactionFilter();

  /// Number of active (non-null, non-default) filters.
  int get activeFilterCount {
    int count = 0;
    if (searchQuery != null && searchQuery!.isNotEmpty) count++;
    if (typeFilter != null && typeFilter != 'all') count++;
    if (dateFrom != null || dateTo != null) count++;
    if (amountMin != null || amountMax != null) count++;
    if (sortBy != 'date_desc') count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

  CustomerTransactionFilter copyWith({
    String? searchQuery,
    bool clearSearchQuery = false,
    String? typeFilter,
    bool clearTypeFilter = false,
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
    return CustomerTransactionFilter(
      searchQuery:
          clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      typeFilter:
          clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      amountMin: clearAmountMin ? null : (amountMin ?? this.amountMin),
      amountMax: clearAmountMax ? null : (amountMax ?? this.amountMax),
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// Reset all filters back to defaults.
  CustomerTransactionFilter clearAll() => const CustomerTransactionFilter();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerTransactionFilter &&
          runtimeType == other.runtimeType &&
          searchQuery == other.searchQuery &&
          typeFilter == other.typeFilter &&
          dateFrom == other.dateFrom &&
          dateTo == other.dateTo &&
          amountMin == other.amountMin &&
          amountMax == other.amountMax &&
          sortBy == other.sortBy;

  @override
  int get hashCode => Object.hash(
        searchQuery,
        typeFilter,
        dateFrom,
        dateTo,
        amountMin,
        amountMax,
        sortBy,
      );

  @override
  String toString() =>
      'CustomerTransactionFilter(query=$searchQuery, type=$typeFilter, '
      'date=$dateFrom..$dateTo, amount=$amountMin..$amountMax, sort=$sortBy, '
      'active=$activeFilterCount)';
}
