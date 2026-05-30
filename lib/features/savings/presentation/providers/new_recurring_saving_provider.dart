import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/savings_repository.dart';
import '../../data/providers/savings_providers.dart';
import '../../../home/data/providers/dashboard_providers.dart'
    show pendingDepositsProvider, dashboardSavingsProvider, activeSavingsProvider;
import '../../../../core/constants/enums.dart' show TenureUnit;

enum CollectionType { daily, weekly, monthly }

class NewRecurringSavingState {
  final String? memberId;
  final CollectionType collectionType;
  final double installmentAmount;
  final double maturityAmount;
  final double initialBalance;
  final DateTime startDate;
  final int tenure;
  final TenureUnit tenureUnit;
  final DateTime maturityDate;
  final double prematurePenalty;
  final bool isLoading;

  NewRecurringSavingState({
    this.memberId,
    this.collectionType = CollectionType.monthly,
    this.installmentAmount = 1000,
    this.maturityAmount = 12500,
    this.initialBalance = 0,
    DateTime? startDate,
    this.tenure = 12,
    this.tenureUnit = TenureUnit.months,
    DateTime? maturityDate,
    this.prematurePenalty = 2,
    this.isLoading = false,
  })  : startDate = startDate ?? DateTime.now(),
        maturityDate = maturityDate ??
            _calculateMaturityDate(
              startDate ?? DateTime.now(),
              tenureUnit,
              tenure,
            );

  static DateTime _calculateMaturityDate(
    DateTime startDate,
    TenureUnit tenureUnit,
    int tenure,
  ) {
    if (tenure <= 0) return startDate;
    switch (tenureUnit) {
      case TenureUnit.days:
        return startDate.add(Duration(days: tenure));
      case TenureUnit.weeks:
        return startDate.add(Duration(days: tenure * 7));
      case TenureUnit.months:
        // Handle month overflow correctly
        final newMonth = startDate.month + tenure;
        final yearOverflow = (newMonth - 1) ~/ 12;
        final month = ((newMonth - 1) % 12) + 1;
        final day = startDate.day.clamp(
            1, _daysInMonth(startDate.year + yearOverflow, month));
        return DateTime(startDate.year + yearOverflow, month, day);
      case TenureUnit.years:
        // Handle leap year edge case (Feb 29 -> Feb 28)
        final targetYear = startDate.year + tenure;
        final day = startDate.day.clamp(1, _daysInMonth(targetYear, startDate.month));
        return DateTime(targetYear, startDate.month, day);
    }
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  NewRecurringSavingState copyWith({
    String? memberId,
    CollectionType? collectionType,
    double? installmentAmount,
    double? maturityAmount,
    double? initialBalance,
    DateTime? startDate,
    int? tenure,
    TenureUnit? tenureUnit,
    DateTime? maturityDate,
    double? prematurePenalty,
    bool? isLoading,
  }) {
    final newStartDate = startDate ?? this.startDate;
    final newTenure = tenure ?? this.tenure;
    final newCollectionType = collectionType ?? this.collectionType;
    final newTenureUnit = tenureUnit ?? this.tenureUnit;

    // Auto-calculate maturity date when start date, tenure, or tenure unit changes
    final shouldRecalculate = startDate != null ||
        tenure != null ||
        tenureUnit != null;

    final newMaturityDate = shouldRecalculate
        ? _calculateMaturityDate(newStartDate, newTenureUnit, newTenure)
        : (maturityDate ?? this.maturityDate);

    return NewRecurringSavingState(
      memberId: memberId ?? this.memberId,
      collectionType: newCollectionType,
      installmentAmount: installmentAmount ?? this.installmentAmount,
      maturityAmount: maturityAmount ?? this.maturityAmount,
      initialBalance: initialBalance ?? this.initialBalance,
      startDate: newStartDate,
      tenure: newTenure,
      tenureUnit: newTenureUnit,
      maturityDate: newMaturityDate,
      prematurePenalty: prematurePenalty ?? this.prematurePenalty,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get totalInstallments {
    if (tenure <= 0) return 0;
    int totalDays;
    switch (tenureUnit) {
      case TenureUnit.days:
        totalDays = tenure;
        break;
      case TenureUnit.weeks:
        totalDays = tenure * 7;
        break;
      case TenureUnit.months:
        totalDays = (tenure * 30.44).round();
        break;
      case TenureUnit.years:
        totalDays = (tenure * 365.25).round();
        break;
    }
    switch (collectionType) {
      case CollectionType.daily:
        return totalDays;
      case CollectionType.weekly:
        return (totalDays / 7).round();
      case CollectionType.monthly:
        return (totalDays / 30.44).round();
    }
  }

  double get totalCapitalInvested {
    return initialBalance + (installmentAmount * totalInstallments);
  }

  double get estimatedInterest {
    return maturityAmount - totalCapitalInvested;
  }
}

class NewRecurringSavingNotifier
    extends StateNotifier<NewRecurringSavingState> {
  final SavingsRepository _repository;
  final Ref _ref;

  NewRecurringSavingNotifier(this._repository, this._ref)
      : super(NewRecurringSavingState());

  void updateMember(String? id) => state = state.copyWith(memberId: id);
  void updateCollectionType(CollectionType type) =>
      state = state.copyWith(collectionType: type);
  void updateInstallmentAmount(double amount) =>
      state = state.copyWith(installmentAmount: amount);
  void updateMaturityAmount(double amount) =>
      state = state.copyWith(maturityAmount: amount);
  void updateInitialBalance(double amount) =>
      state = state.copyWith(initialBalance: amount);
  void updateStartDate(DateTime date) =>
      state = state.copyWith(startDate: date);
  void updateTenure(int value) => state = state.copyWith(tenure: value);
  void updateTenureUnit(TenureUnit unit) =>
      state = state.copyWith(tenureUnit: unit);
  void updateMaturityDate(DateTime date) =>
      state = state.copyWith(maturityDate: date);
  void updatePrematurePenalty(double penalty) =>
      state = state.copyWith(prematurePenalty: penalty);

  Future<void> createSavingsPlan() async {
    if (state.memberId == null) throw Exception('Please select a member');

    state = state.copyWith(isLoading: true);
    try {
      await _repository.createSavingsPlan(
        memberId: state.memberId!,
        installmentAmount: state.installmentAmount,
        maturityAmount: state.maturityAmount,
        maturityDate: state.maturityDate,
        collectionType: state.collectionType.name,
        penalty: state.prematurePenalty,
        totalInstallments: state.totalInstallments,
        startDate: state.startDate,
        tenure: state.tenure,
        tenureUnit: state.tenureUnit.name,
        openingBalance: state.initialBalance,
      );

      // Invalidate providers to refresh the list
      _ref.invalidate(allSavingsProvider);
      _ref.invalidate(savingsSummaryProvider);
      _ref.invalidate(pendingDepositsProvider);
      _ref.invalidate(dashboardSavingsProvider);
      _ref.invalidate(activeSavingsProvider);

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  void reset() => state = NewRecurringSavingState();
}

final newRecurringSavingProvider =
    StateNotifierProvider<NewRecurringSavingNotifier, NewRecurringSavingState>(
        (ref) {
  return NewRecurringSavingNotifier(ref.watch(savingsRepositoryProvider), ref);
});
