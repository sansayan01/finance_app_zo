import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/loans_repository.dart';
import 'loan_providers.dart';
import '../../../home/data/providers/dashboard_providers.dart' show loanSummaryProvider, dashboardLoansProvider, todayStatsProvider, todayAgendaProvider;
import '../../../../core/constants/enums.dart' show TenureUnit;

enum InterestLogic { reducingBalance, flat }

enum CollectionType { daily, weekly, monthly, yearly }

enum InterestMode { rate, amount }

enum InterestBasis { daily, weekly, monthly, yearly, onPrincipal }

class AmortizationRow {
  final int emiNumber;
  final DateTime dueDate;
  final double emiAmount;
  final double principal;
  final double interest;
  final double balanceAfter;

  AmortizationRow({
    required this.emiNumber,
    required this.dueDate,
    required this.emiAmount,
    required this.principal,
    required this.interest,
    required this.balanceAfter,
  });
}

class NewLoanState {
  final String? borrowerId;
  final double principalAmount;
  final InterestMode interestMode;
  final double interestRate;
  final InterestBasis interestRateBasis;
  final double interestAmount;
  final InterestBasis interestBasis;
  final int tenureValue;
  final TenureUnit tenureUnit;
  final CollectionType collectionType;
  final InterestLogic interestLogic;
  final DateTime? firstInstallmentDate;
  final DateTime? disbursementDate;
  final bool isLoading;

  // Migration fields
  final int paidEmis;
  final DateTime? lastPaymentDate;
  final double openingBalance;
  final double outstandingBalance;

  NewLoanState({
    this.borrowerId,
    this.principalAmount = 50000,
    this.interestMode = InterestMode.rate,
    this.interestRate = 2,
    this.interestRateBasis = InterestBasis.monthly,
    this.interestAmount = 0,
    this.interestBasis = InterestBasis.monthly,
    this.tenureValue = 12,
    this.tenureUnit = TenureUnit.months,
    this.collectionType = CollectionType.monthly,
    this.interestLogic = InterestLogic.reducingBalance,
    this.firstInstallmentDate,
    this.disbursementDate,
    this.isLoading = false,
    this.paidEmis = 0,
    this.lastPaymentDate,
    this.openingBalance = 0,
    this.outstandingBalance = 0,
  });

  NewLoanState copyWith({
    String? borrowerId,
    double? principalAmount,
    InterestMode? interestMode,
    double? interestRate,
    InterestBasis? interestRateBasis,
    double? interestAmount,
    InterestBasis? interestBasis,
    int? tenureValue,
    TenureUnit? tenureUnit,
    CollectionType? collectionType,
    InterestLogic? interestLogic,
    DateTime? firstInstallmentDate,
    DateTime? disbursementDate,
    bool? isLoading,
    int? paidEmis,
    DateTime? lastPaymentDate,
    double? openingBalance,
    double? outstandingBalance,
  }) {
    return NewLoanState(
      borrowerId: borrowerId ?? this.borrowerId,
      principalAmount: principalAmount ?? this.principalAmount,
      interestMode: interestMode ?? this.interestMode,
      interestRate: interestRate ?? this.interestRate,
      interestRateBasis: interestRateBasis ?? this.interestRateBasis,
      interestAmount: interestAmount ?? this.interestAmount,
      interestBasis: interestBasis ?? this.interestBasis,
      tenureValue: tenureValue ?? this.tenureValue,
      tenureUnit: tenureUnit ?? this.tenureUnit,
      collectionType: collectionType ?? this.collectionType,
      interestLogic: interestLogic ?? this.interestLogic,
      firstInstallmentDate: firstInstallmentDate ?? this.firstInstallmentDate,
      disbursementDate: disbursementDate ?? this.disbursementDate,
      isLoading: isLoading ?? this.isLoading,
      paidEmis: paidEmis ?? this.paidEmis,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      openingBalance: openingBalance ?? this.openingBalance,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
    );
  }

  int get _daysPerCollectionPeriod {
    switch (collectionType) {
      case CollectionType.daily:
        return 1;
      case CollectionType.weekly:
        return 7;
      case CollectionType.monthly:
        return 30;
      case CollectionType.yearly:
        return 365;
    }
  }

  int get tenureInDays {
    switch (tenureUnit) {
      case TenureUnit.days:
        return tenureValue;
      case TenureUnit.weeks:
        return tenureValue * 7;
      case TenureUnit.months:
        return tenureValue * 30;
      case TenureUnit.years:
        return tenureValue * 365;
    }
  }

  double get tenureInYears => tenureInDays / 365;

  /// Number of installments already paid (migration)
  int get installmentsPaidCount => paidEmis;

  /// Number of installments remaining after migration
  int get remainingInstallments => numberOfInstallments - paidEmis;

  /// Next due date: computed from firstInstallmentDate + paidEmis periods
  DateTime? get nextDueDateCalc {
    if (firstInstallmentDate == null) return null;
    final start = firstInstallmentDate!;
    switch (collectionType) {
      case CollectionType.daily:
        return start.add(Duration(days: paidEmis));
      case CollectionType.weekly:
        return start.add(Duration(days: paidEmis * 7));
      case CollectionType.yearly:
        return DateTime(start.year + paidEmis, start.month, start.day);
      case CollectionType.monthly:
        int targetMonth = start.month + paidEmis;
        int targetYear = start.year + ((targetMonth - 1) ~/ 12);
        targetMonth = ((targetMonth - 1) % 12) + 1;
        int targetDay = start.day;
        int daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
        if (targetDay > daysInMonth) targetDay = daysInMonth;
        return DateTime(targetYear, targetMonth, targetDay);
    }
  }

  /// Total expected installments from start to today (for overdue calc)
  int _expectedInstallmentsByDate(DateTime date) {
    if (firstInstallmentDate == null) return 0;
    final daysSinceStart = date.difference(firstInstallmentDate!).inDays;
    switch (collectionType) {
      case CollectionType.daily:
        return daysSinceStart + 1;
      case CollectionType.weekly:
        return (daysSinceStart ~/ 7) + 1;
      case CollectionType.yearly:
        return (daysSinceStart ~/ 365) + 1;
      case CollectionType.monthly:
        int months = (date.year - firstInstallmentDate!.year) * 12 +
            (date.month - firstInstallmentDate!.month);
        if (date.day >= firstInstallmentDate!.day) months++;
        return months;
    }
  }

  /// Number of overdue installments (migration-aware)
  int get overdueInstallments {
    final expectedByNow = _expectedInstallmentsByDate(DateTime.now());
    final overdue = expectedByNow - paidEmis;
    return overdue > 0 ? overdue : 0;
  }

  /// Overdue amount
  double get overdueAmount => overdueInstallments * estimatedInstallment;

  /// Whether this is a migrated loan
  bool get isMigrated => paidEmis > 0;

  int get numberOfInstallments {
    if (tenureInDays <= 0) return 0;
    return (tenureInDays / _daysPerCollectionPeriod).round().clamp(1, 100000);
  }

  double get _periodsPerYear {
    switch (collectionType) {
      case CollectionType.daily:
        return 365;
      case CollectionType.weekly:
        return 52;
      case CollectionType.monthly:
        return 12;
      case CollectionType.yearly:
        return 1;
    }
  }

  double get annualizedRate {
    double rate = interestRate / 100;
    switch (interestRateBasis) {
      case InterestBasis.daily:
        return rate * 365;
      case InterestBasis.weekly:
        return rate * 52;
      case InterestBasis.monthly:
        return rate * 12;
      case InterestBasis.yearly:
        return rate;
      case InterestBasis.onPrincipal:
        return rate * (365 / tenureInDays);
    }
  }

  double get _ratePerPeriod {
    return annualizedRate / _periodsPerYear;
  }

  double get _totalInterestAmount {
    if (principalAmount <= 0 || tenureInDays <= 0) return 0;

    if (interestMode == InterestMode.amount) {
      double periodsInTenure;
      switch (interestBasis) {
        case InterestBasis.onPrincipal:
          return interestAmount;
        case InterestBasis.daily:
          periodsInTenure = tenureInDays.toDouble();
          break;
        case InterestBasis.weekly:
          periodsInTenure = tenureInDays / 7;
          break;
        case InterestBasis.monthly:
          periodsInTenure = tenureInDays / 30;
          break;
        case InterestBasis.yearly:
          periodsInTenure = tenureInDays / 365;
          break;
      }
      return interestAmount * periodsInTenure;
    }

    if (interestLogic == InterestLogic.flat) {
      return principalAmount * annualizedRate * tenureInYears;
    }

    int n = numberOfInstallments;
    if (n <= 0) return 0;

    double r = _ratePerPeriod;
    if (r == 0) return 0;

    double totalPayment =
        (principalAmount * r * pow(1 + r, n)) / (pow(1 + r, n) - 1) * n;
    return totalPayment - principalAmount;
  }

  double get estimatedInstallment {
    if (principalAmount <= 0 || tenureInDays <= 0) return 0;

    if (interestMode == InterestMode.amount) {
      double totalInterest = _totalInterestAmount;
      return (principalAmount + totalInterest) / numberOfInstallments;
    }

    int n = numberOfInstallments;
    if (n <= 0) return 0;

    double r = _ratePerPeriod;
    double p = principalAmount;

    if (r == 0) {
      return p / n;
    }

    if (interestLogic == InterestLogic.reducingBalance) {
      return (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
    } else {
      double totalInterest = principalAmount * annualizedRate * tenureInYears;
      return (p + totalInterest) / n;
    }
  }

  double get totalInterest {
    if (interestMode == InterestMode.amount) {
      return _totalInterestAmount;
    }
    return (estimatedInstallment * numberOfInstallments) - principalAmount;
  }

  double get interestBurden => totalInterest;

  double get totalExposure => principalAmount + totalInterest;

  List<AmortizationRow> generateAmortizationSchedule() {
    if (principalAmount <= 0 || tenureInDays <= 0) return [];

    final rows = <AmortizationRow>[];
    double balance = principalAmount;
    int n = numberOfInstallments;
    if (n <= 0) return [];

    double emi;
    double fixedInterestPerInstallment = 0;

    if (interestMode == InterestMode.amount) {
      double totalInterest = _totalInterestAmount;
      emi = (principalAmount + totalInterest) / n;
      fixedInterestPerInstallment = totalInterest / n;
    } else {
      double r = _ratePerPeriod;
      if (r == 0) {
        emi = principalAmount / n;
      } else if (interestLogic == InterestLogic.reducingBalance) {
        emi = (principalAmount * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
      } else {
        double totalInterest = principalAmount * annualizedRate * tenureInYears;
        emi = (principalAmount + totalInterest) / n;
      }
    }

    DateTime startDate =
        firstInstallmentDate ?? DateTime.now().add(const Duration(days: 30));

    for (int i = 1; i <= n; i++) {
      double interestPart;
      double principalPart;

      if (interestMode == InterestMode.amount) {
        interestPart = fixedInterestPerInstallment;
        principalPart = emi - interestPart;
      } else if (interestLogic == InterestLogic.reducingBalance) {
        double r = _ratePerPeriod;
        interestPart = balance * r;
        principalPart = emi - interestPart;
      } else {
        double totalInterest = principalAmount * annualizedRate * tenureInYears;
        interestPart = totalInterest / n;
        principalPart = emi - interestPart;
      }

      if (i == n) {
        principalPart = balance;
        interestPart = interestMode == InterestMode.amount
            ? fixedInterestPerInstallment
            : (interestLogic == InterestLogic.reducingBalance
                ? balance * _ratePerPeriod
                : interestPart);
        emi = principalPart + interestPart;
      }

      balance -= principalPart;
      if (balance < 0) balance = 0;

      DateTime dueDate;
      switch (collectionType) {
        case CollectionType.daily:
          dueDate = startDate.add(Duration(days: i - 1));
          break;
        case CollectionType.weekly:
          dueDate = startDate.add(Duration(days: (i - 1) * 7));
          break;
        case CollectionType.yearly:
          dueDate = DateTime(
              startDate.year + (i - 1), startDate.month, startDate.day);
          break;
        case CollectionType.monthly:
          dueDate = DateTime(
              startDate.year, startDate.month + (i - 1), startDate.day);
          break;
      }

      rows.add(AmortizationRow(
        emiNumber: i,
        dueDate: dueDate,
        emiAmount: emi,
        principal: principalPart,
        interest: interestPart,
        balanceAfter: balance,
      ));
    }

    return rows;
  }
}

class NewLoanNotifier extends StateNotifier<NewLoanState> {
  final LoansRepository _repository;
  final Ref _ref;

  NewLoanNotifier(this._repository, this._ref) : super(NewLoanState());

  void updateBorrower(String? id) => state = state.copyWith(borrowerId: id);
  void updatePrincipal(double amount) =>
      state = state.copyWith(principalAmount: amount);
  void updateInterestMode(InterestMode mode) =>
      state = state.copyWith(interestMode: mode);
  void updateInterestRate(double rate) =>
      state = state.copyWith(interestRate: rate);
  void updateInterestRateBasis(InterestBasis basis) =>
      state = state.copyWith(interestRateBasis: basis);
  void updateInterestAmount(double amount) =>
      state = state.copyWith(interestAmount: amount);
  void updateInterestBasis(InterestBasis basis) =>
      state = state.copyWith(interestBasis: basis);
  void updateTenureValue(int value) =>
      state = state.copyWith(tenureValue: value);
  void updateTenureUnit(TenureUnit unit) =>
      state = state.copyWith(tenureUnit: unit);
  void updateCollectionType(CollectionType type) =>
      state = state.copyWith(collectionType: type);
  void updateInterestLogic(InterestLogic logic) =>
      state = state.copyWith(interestLogic: logic);
  void updateFirstInstallmentDate(DateTime date) =>
      state = state.copyWith(firstInstallmentDate: date);
  void updateDisbursementDate(DateTime date) =>
      state = state.copyWith(disbursementDate: date);

  // Migration field updates
  void updatePaidEmis(int count) =>
      state = state.copyWith(paidEmis: count);
  void updateLastPaymentDate(DateTime date) =>
      state = state.copyWith(lastPaymentDate: date);
  void updateOutstandingBalance(double amount) =>
      state = state.copyWith(outstandingBalance: amount);
  void updateOpeningBalance(double amount) =>
      state = state.copyWith(openingBalance: amount);

  void enableMigration({
    required int paidEmis,
    DateTime? lastPaymentDate,
    required double outstandingBalance,
    required double openingBalance,
  }) {
    state = state.copyWith(
      paidEmis: paidEmis,
      lastPaymentDate: lastPaymentDate,
      outstandingBalance: outstandingBalance,
      openingBalance: openingBalance,
    );
  }

  void disableMigration() {
    state = state.copyWith(
      paidEmis: 0,
      lastPaymentDate: null,
      outstandingBalance: 0,
      openingBalance: 0,
    );
  }

  DateTime _computeLastPaymentDate() {
    final start = state.firstInstallmentDate;
    if (start == null || state.paidEmis <= 0) return DateTime.now();
    int daysPerPeriod;
    switch (state.collectionType) {
      case CollectionType.daily:
        daysPerPeriod = 1;
        break;
      case CollectionType.weekly:
        daysPerPeriod = 7;
        break;
      case CollectionType.monthly:
        daysPerPeriod = 30;
        break;
      case CollectionType.yearly:
        daysPerPeriod = 365;
        break;
    }
    return start.add(Duration(days: daysPerPeriod * (state.paidEmis - 1)));
  }

  Future<void> createLoan() async {
    if (state.borrowerId == null) throw Exception('Please select a borrower');

    state = state.copyWith(isLoading: true);
    try {
      final bool isMigrated = state.isMigrated;

      final String loanId;
      if (isMigrated) {
        // ── Migration Path ──
        final double emi = state.estimatedInstallment;
        // Store the ORIGINAL first installment date (not next due) so the
        // EMI schedule and collection records align on the same base date.
        final DateTime loanStartDate =
            state.firstInstallmentDate ?? DateTime.now();

        loanId = await _repository.createMigrationLoan(
          borrowerId: state.borrowerId!,
          principal: state.principalAmount,
          interestRate: state.interestMode == InterestMode.rate
              ? state.interestRate
              : _calculateEquivalentAPR(),
          tenureMonths: state.tenureValue,
          frequency: state.collectionType.name,
          collectionType: state.collectionType.name,
          interestLogic: state.interestLogic.name,
          firstInstallmentDate: loanStartDate,
          disbursementDate: state.disbursementDate,
          estimatedInstallment: emi,
          totalExposure: state.totalExposure,
          paidEmis: state.paidEmis,
          lastPaymentDate: state.lastPaymentDate ?? _computeLastPaymentDate(),
          outstandingBalance: state.outstandingBalance > 0
              ? state.outstandingBalance
              : (state.totalExposure -
                      state.paidEmis * state.estimatedInstallment)
                  .clamp(0, state.totalExposure),
          openingBalance: state.paidEmis * state.estimatedInstallment,
          interestMode: state.interestMode.name,
          interestRateBasis: state.interestMode == InterestMode.rate
              ? state.interestRateBasis.name
              : null,
          interestAmount: state.interestMode == InterestMode.amount
              ? state.interestAmount
              : 0,
          interestBasis: state.interestMode == InterestMode.amount
              ? state.interestBasis.name
              : null,
          tenureValue: state.tenureValue,
          tenureUnit: state.tenureUnit.name,
        );

        // Generate full EMI schedule marking first N as paid
        try {
          final emiRepo = _ref.read(emiRepositoryProvider);
          await emiRepo.generateSchedule(
            loanId,
            principal: state.principalAmount,
            interestRate: state.interestMode == InterestMode.rate
                ? state.interestRate
                : _calculateEquivalentAPR(),
            tenureMonths: state.tenureValue,
            interestType: state.interestLogic.name,
            startDate: loanStartDate,
            emiAmount: state.estimatedInstallment,
            memberId: state.borrowerId,
            frequency: state.collectionType.name,
            tenureValue: state.tenureValue,
            tenureUnit: state.tenureUnit.name,
            paidEmis: state.paidEmis,
            lastPaymentDate: state.lastPaymentDate ?? _computeLastPaymentDate(),
          );
        } catch (e) {
          debugPrint('Warning: EMI schedule generation failed: $e');
        }

        // Create synthetic collection records for paid installments
        try {
          await _repository.createMigrationLoanCollectionRecords(
            loanId: loanId,
            memberId: state.borrowerId!,
            installmentAmount: state.estimatedInstallment,
            installmentsPaid: state.paidEmis,
            startDate: state.firstInstallmentDate ?? DateTime.now(),
            collectionType: state.collectionType.name,
          );
        } catch (e) {
          debugPrint('Warning: Migration collection records failed: $e');
        }
      } else {
        // ── Normal Path ──
        loanId = await _repository.createLoan(
          borrowerId: state.borrowerId!,
          principal: state.principalAmount,
          interestRate: state.interestMode == InterestMode.rate
              ? state.interestRate
              : _calculateEquivalentAPR(),
          tenureMonths: state.tenureValue,
          frequency: state.collectionType.name,
          collectionType: state.collectionType.name,
          interestLogic: state.interestLogic.name,
          firstInstallmentDate: state.firstInstallmentDate ??
              DateTime.now().add(const Duration(days: 30)),
          disbursementDate: state.disbursementDate ?? DateTime.now(),
          estimatedInstallment: state.estimatedInstallment,
          totalExposure: state.totalExposure,
          interestMode: state.interestMode.name,
          interestRateBasis: state.interestMode == InterestMode.rate
              ? state.interestRateBasis.name
              : null,
          interestAmount: state.interestMode == InterestMode.amount
              ? state.interestAmount
              : 0,
          interestBasis: state.interestMode == InterestMode.amount
              ? state.interestBasis.name
              : null,
          tenureValue: state.tenureValue,
          tenureUnit: state.tenureUnit.name,
        );

        // Generate EMI schedule
        try {
          final emiRepo = _ref.read(emiRepositoryProvider);
          await emiRepo.generateSchedule(
            loanId,
            principal: state.principalAmount,
            interestRate: state.interestMode == InterestMode.rate
                ? state.interestRate
                : _calculateEquivalentAPR(),
            tenureMonths: state.tenureValue,
            interestType: state.interestLogic.name,
            startDate: state.firstInstallmentDate ?? DateTime.now(),
            emiAmount: state.estimatedInstallment,
            memberId: state.borrowerId,
            frequency: state.collectionType.name,
            tenureValue: state.tenureValue,
            tenureUnit: state.tenureUnit.name,
          );
        } catch (e) {
          debugPrint('Warning: EMI schedule generation failed: $e');
        }
      }

      _ref.invalidate(loansProvider);
      _ref.invalidate(loanSummaryProvider);
      _ref.invalidate(dashboardLoansProvider);
      _ref.invalidate(todayStatsProvider);
      _ref.invalidate(todayAgendaProvider);

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  double _calculateEquivalentAPR() {
    if (state.interestAmount <= 0 || state.tenureInDays <= 0) return 0;

    double totalInterest;
    switch (state.interestBasis) {
      case InterestBasis.onPrincipal:
        return state.interestAmount * (365 / state.tenureInDays);
      case InterestBasis.daily:
        totalInterest = state.interestAmount * state.tenureInDays;
        break;
      case InterestBasis.weekly:
        totalInterest = state.interestAmount * (state.tenureInDays / 7);
        break;
      case InterestBasis.monthly:
        totalInterest = state.interestAmount * (state.tenureInDays / 30);
        break;
      case InterestBasis.yearly:
        totalInterest = state.interestAmount * (state.tenureInDays / 365);
        break;
    }
    return (totalInterest / state.principalAmount) *
        (365 / state.tenureInDays) *
        100;
  }

  void reset() => state = NewLoanState();
}

final newLoanProvider =
    StateNotifierProvider<NewLoanNotifier, NewLoanState>((ref) {
  return NewLoanNotifier(ref.watch(loansRepositoryProvider), ref);
});
