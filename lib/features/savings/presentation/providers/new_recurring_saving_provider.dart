import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/savings_repository.dart';
import '../../data/providers/savings_providers.dart';
import '../../../home/data/providers/dashboard_providers.dart'
    show pendingDepositsProvider, dashboardSavingsProvider, activeSavingsProvider;

enum CollectionType { daily, weekly, monthly }

class NewRecurringSavingState {
  final String? memberId;
  final CollectionType collectionType;
  final double installmentAmount;
  final double maturityAmount;
  final double initialBalance;
  final DateTime maturityDate;
  final double prematurePenalty;
  final bool isLoading;

  NewRecurringSavingState({
    this.memberId,
    this.collectionType = CollectionType.monthly,
    this.installmentAmount = 1000,
    this.maturityAmount = 12500,
    this.initialBalance = 0,
    DateTime? maturityDate,
    this.prematurePenalty = 2,
    this.isLoading = false,
  }) : maturityDate =
            maturityDate ?? DateTime.now().add(const Duration(days: 365));

  NewRecurringSavingState copyWith({
    String? memberId,
    CollectionType? collectionType,
    double? installmentAmount,
    double? maturityAmount,
    double? initialBalance,
    DateTime? maturityDate,
    double? prematurePenalty,
    bool? isLoading,
  }) {
    return NewRecurringSavingState(
      memberId: memberId ?? this.memberId,
      collectionType: collectionType ?? this.collectionType,
      installmentAmount: installmentAmount ?? this.installmentAmount,
      maturityAmount: maturityAmount ?? this.maturityAmount,
      initialBalance: initialBalance ?? this.initialBalance,
      maturityDate: maturityDate ?? this.maturityDate,
      prematurePenalty: prematurePenalty ?? this.prematurePenalty,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get totalInstallments {
    final now = DateTime.now();
    if (maturityDate.isBefore(now)) return 0;

    final days = maturityDate.difference(now).inDays;
    switch (collectionType) {
      case CollectionType.daily:
        return days;
      case CollectionType.weekly:
        return (days / 7).round();
      case CollectionType.monthly:
        // approximate months
        return (days / 30.44).round();
    }
  }

  double get totalCapitalInvested {
    return installmentAmount * totalInstallments;
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
  void updateMaturityDate(DateTime date) =>
      state = state.copyWith(maturityDate: date);
  void updatePrematurePenalty(double penalty) =>
      state = state.copyWith(prematurePenalty: penalty);

  Future<void> createSavingsPlan() async {
    if (state.memberId == null) throw Exception('Please select a member');

    state = state.copyWith(isLoading: true);
    try {
      final newSavingId = await _repository.createSavingsPlan(
        memberId: state.memberId!,
        installmentAmount: state.installmentAmount,
        maturityAmount: state.maturityAmount,
        maturityDate: state.maturityDate,
        collectionType: state.collectionType.name,
        penalty: state.prematurePenalty,
        totalInstallments: state.totalInstallments,
      );

      // If there is an initial balance (migrated account), record it immediately
      if (state.initialBalance > 0) {
        await _repository.recordDeposit(newSavingId, state.initialBalance);
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
}

final newRecurringSavingProvider =
    StateNotifierProvider<NewRecurringSavingNotifier, NewRecurringSavingState>(
        (ref) {
  return NewRecurringSavingNotifier(ref.watch(savingsRepositoryProvider), ref);
});
