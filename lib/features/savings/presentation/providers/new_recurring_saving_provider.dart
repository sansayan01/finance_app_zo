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
  final bool freezeEnabled;

  // Phase #3 — explicit migration flag. Until set to true, the
  // alreadyPaidAmount / installmentsPaid fields are stored but
  // ignored by createSavingsPlan (normal new-plan path).
  final bool isMigrated;
  final int installmentsPaid;
  final double alreadyPaidAmount;

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
    this.freezeEnabled = false,
    this.isMigrated = false,
    this.installmentsPaid = 0,
    this.alreadyPaidAmount = 0,
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
    bool? freezeEnabled,
    bool? isMigrated,
    int? installmentsPaid,
    double? alreadyPaidAmount,
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
      freezeEnabled: freezeEnabled ?? this.freezeEnabled,
      isMigrated: isMigrated ?? this.isMigrated,
      installmentsPaid: installmentsPaid ?? this.installmentsPaid,
      alreadyPaidAmount: alreadyPaidAmount ?? this.alreadyPaidAmount,
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

  /// Number of installments that have been paid, computed from alreadyPaidAmount.
  int get installmentsPaidCount {
    if (installmentAmount <= 0 || alreadyPaidAmount <= 0) return 0;
    return (alreadyPaidAmount / installmentAmount).floor();
  }

  /// Number of installments past the next expected due installment.
  int get overdueInstallments {
    final expectedByNow = _expectedInstallmentsByDate(DateTime.now());
    final overdue = expectedByNow - installmentsPaidCount;
    return overdue > 0 ? overdue : 0;
  }

  /// Amount overdue (overdue installments × installment amount).
  double get overdueAmount => overdueInstallments * installmentAmount;

  /// Auto-calculated next due date based on installments paid.
  DateTime get nextDueDateCalc => _computeNextDueDateFromStart(
        startDate: startDate,
        installmentsPaid: installmentsPaidCount,
        collectionType: collectionType,
      );

  /// Expected number of installments from start to [date].
  int _expectedInstallmentsByDate(DateTime date) {
    final daysSinceStart = date.difference(startDate).inDays;
    switch (collectionType) {
      case CollectionType.daily:
        return daysSinceStart + 1;
      case CollectionType.weekly:
        return (daysSinceStart ~/ 7) + 1;
      case CollectionType.monthly:
        int months = (date.year - startDate.year) * 12 +
            (date.month - startDate.month);
        if (date.day >= startDate.day) months++;
        return months;
    }
  }

  static DateTime _computeNextDueDateFromStart({
    required DateTime startDate,
    required int installmentsPaid,
    required CollectionType collectionType,
  }) {
    final offset = installmentsPaid; // next unpaid index
    switch (collectionType) {
      case CollectionType.daily:
        return startDate.add(Duration(days: offset));
      case CollectionType.weekly:
        return startDate.add(Duration(days: offset * 7));
      case CollectionType.monthly:
        return DateTime(
          startDate.year,
          startDate.month + offset,
          startDate.day,
        );
    }
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
  void updateFreezeEnabled(bool enabled) =>
      state = state.copyWith(freezeEnabled: enabled);

  // Phase #3 — explicit migration flag. Routes to the migration code path
  // in [createSavingsPlan] only when the user has toggled this on.
  void updateIsMigrated(bool enabled) =>
      state = state.copyWith(isMigrated: enabled);

  /// Update alreadyPaidAmount and auto-calculate installmentsPaid.
  void updateAlreadyPaidAmount(double amount) {
    final computedInstallments = state.installmentAmount > 0
        ? (amount / state.installmentAmount).floor()
        : 0;
    state = state.copyWith(
      alreadyPaidAmount: amount,
      installmentsPaid: computedInstallments,
    );
  }

  Future<void> createSavingsPlan() async {
    if (state.memberId == null) throw Exception('Please select a member');

    state = state.copyWith(isLoading: true);
    try {
      // Route migrated accounts to the dedicated migration method
      // which correctly computes current_amount, next_due_date, maturity_date
      // Phase #3 — the migration code path is taken ONLY when the user has
      // explicitly toggled the "is migrated" checkbox. The previous route
      // (auto-deriving from alreadyPaidAmount > 0) caught every brand-new
      // plan that happened to start with any back-fill amount.
      if (state.isMigrated) {
        // Use installmentsPaidCount (live getter) instead of installmentsPaid (stale field)
        // because installmentsPaid may be 0 if the user entered alreadyPaidAmount
        // before setting the installmentAmount.
        final paidDays = state.installmentsPaidCount;
        final lastPayment = _lastPaymentDateFromStart(
          startDate: state.startDate,
          installmentsPaid: paidDays,
          collectionType: state.collectionType,
        );
        final migration = await _repository.createMigrationSavingsPlan(
          memberId: state.memberId!,
          installmentAmount: state.installmentAmount,
          totalReturnAmount: state.maturityAmount,
          startDate: state.startDate,
          tenure: state.tenure,
          tenureUnit: state.tenureUnit.name,
          collectionType: state.collectionType.name,
          penalty: state.prematurePenalty,
          installmentsPaid: paidDays,
          lastPaymentDate: lastPayment,
          freezeEnabled: state.freezeEnabled,
        );
        final planId = migration.planId;
        final migrationTxId = migration.transactionId;

        // Create synthetic collection records for already-paid installments
        // so deposit history shows up on the detail page. The
        // migration transaction id is threaded through so every collection
        // row is linked to the synthetic deposit transaction (Phase #1).
        if (planId.isNotEmpty) {
          await _repository.createMigrationCollectionRecords(
            savingsPlanId: planId,
            memberId: state.memberId!,
            installmentAmount: state.installmentAmount,
            installmentsPaid: paidDays,
            startDate: state.startDate,
            collectionType: state.collectionType.name,
            transactionId: migrationTxId,
          );
        }
      } else {
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
          totalReturnAmount: state.alreadyPaidAmount,
          freezeEnabled: state.freezeEnabled,
        );
      }

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

  /// Computes the date of the last paid installment from start + count.
  static DateTime _lastPaymentDateFromStart({
    required DateTime startDate,
    required int installmentsPaid,
    required CollectionType collectionType,
  }) {
    if (installmentsPaid <= 0) return startDate;
    final offset = installmentsPaid - 1; // last paid index (0-based)
    switch (collectionType) {
      case CollectionType.daily:
        return startDate.add(Duration(days: offset));
      case CollectionType.weekly:
        return startDate.add(Duration(days: offset * 7));
      case CollectionType.monthly:
        return DateTime(
          startDate.year,
          startDate.month + offset,
          startDate.day,
        );
    }
  }
}

final newRecurringSavingProvider =
    StateNotifierProvider<NewRecurringSavingNotifier, NewRecurringSavingState>(
        (ref) {
  return NewRecurringSavingNotifier(ref.watch(savingsRepositoryProvider), ref);
});
