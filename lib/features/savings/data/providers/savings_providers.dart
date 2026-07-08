import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/savings_model.dart';
import '../models/savings_installment_model.dart';
import '../repositories/savings_repository.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../transactions/data/repositories/transactions_repository.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../users/presentation/providers/user_list_provider.dart';

final savingsRepositoryProvider = Provider.autoDispose<SavingsRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return SavingsRepository(ref.watch(supabaseClientProvider), orgId);
});

final transactionsRepositoryProvider = Provider.autoDispose<TransactionsRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return TransactionsRepository(ref.watch(supabaseClientProvider), orgId);
});

final allSavingsProvider = FutureProvider.autoDispose<List<SavingsModel>>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getAllSavingsPlans();
});

final savingsSummaryProvider = FutureProvider.autoDispose<SavingsSummary>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getSavingsSummary();
});

// Alias for backward compatibility if needed by other pages
final savingsProvider = allSavingsProvider;

final savingDetailProvider =
    FutureProvider.family.autoDispose<SavingsModel?, String>((ref, id) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getSavingPlanById(id);
});

final savingTransactionsProvider =
    FutureProvider.family.autoDispose<List<TransactionModel>, String>((ref, id) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getTransactionsBySavingsId(id);
});

class SavingTxPageState {
  final List<TransactionModel> items;
  final bool hasMore;
  final bool isLoading;
  final Object? error;

  const SavingTxPageState({
    required this.items,
    required this.hasMore,
    required this.isLoading,
    this.error,
  });

  static const empty = SavingTxPageState(
    items: [],
    hasMore: true,
    isLoading: false,
  );

  SavingTxPageState copyWith({
    List<TransactionModel>? items,
    bool? hasMore,
    bool? isLoading,
    Object? error,
  }) {
    return SavingTxPageState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SavingTxPager extends StateNotifier<SavingTxPageState> {
  SavingTxPager(this._ref, this._savingId) : super(SavingTxPageState.empty) {
    refresh();
  }

  final Ref _ref;
  final String _savingId;
  static const int _pageSize = 10;

  Future<void> refresh() async {
    state = SavingTxPageState.empty.copyWith(isLoading: true);
    try {
      final repo = _ref.read(transactionsRepositoryProvider);
      final page = await repo.getTransactionsBySavingsId(
        _savingId,
        limit: _pageSize,
        offset: 0,
      );
      state = SavingTxPageState(
        items: page,
        hasMore: page.length == _pageSize,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(transactionsRepositoryProvider);
      final page = await repo.getTransactionsBySavingsId(
        _savingId,
        limit: _pageSize,
        offset: state.items.length,
      );
      state = SavingTxPageState(
        items: [...state.items, ...page],
        hasMore: page.length == _pageSize,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}

final savingTxPagerProvider = StateNotifierProvider.family.autoDispose<SavingTxPager,
    SavingTxPageState, String>((ref, id) {
  return SavingTxPager(ref, id);
});

final userSavingsProvider =
    FutureProvider.family.autoDispose<List<SavingsModel>, String>((ref, userId) async {
  final savings = await ref.watch(allSavingsProvider.future);
  final userDetails = await ref.watch(userDetailsProvider(userId).future);
  // userDetails.id is the member table primary key (may differ from userId
  // when userId is a profile ID).  Also match on memberCode.
  final memberPk = userDetails?.id;
  final memberCode = userDetails?.memberCode;
  return savings.where((s) =>
      s.memberId == userId ||
      (memberPk != null && s.memberId == memberPk) ||
      (memberCode != null && s.memberId == memberCode)
  ).toList();
});

final memberSavingsProvider =
    FutureProvider.family.autoDispose<List<SavingsModel>, String>((ref, memberId) async {
  final repo = ref.watch(savingsRepositoryProvider);
  return repo.getPlansByMemberId(memberId);
});

final savingsScheduleProvider =
    FutureProvider.family.autoDispose<List<SavingsInstallment>, String>(
        (ref, planId) async {
  final client = ref.watch(supabaseClientProvider);
  final repo = ref.watch(savingsRepositoryProvider);
  final plan = await repo.getSavingPlanById(planId);
  if (plan == null) return [];
  final paidDates = await SavingsScheduleGenerator.fetchPaidDates(
    client: client,
    planId: planId,
  );
  return SavingsScheduleGenerator.generate(plan: plan, paidDates: paidDates);
});
