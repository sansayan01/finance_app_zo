import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import 'new_user_provider.dart';

/// The four logical sections of the User Hub.
enum UserHubTab { team, customers, invites, suspended }

/// Filter / search / sort state for one tab.
class UserHubQuery {
  final String search;
  final String? branchId;
  final UserRole? roleFilter; // Only meaningful on Team tab.
  final UserSortBy sortBy;

  const UserHubQuery({
    this.search = '',
    this.branchId,
    this.roleFilter,
    this.sortBy = UserSortBy.createdDesc,
  });

  UserHubQuery copyWith({
    String? search,
    Object? branchId = const Object(), // sentinel for "leave alone"
    Object? roleFilter = const Object(),
    UserSortBy? sortBy,
  }) {
    return UserHubQuery(
      search: search ?? this.search,
      branchId:
          branchId == const Object() ? this.branchId : branchId as String?,
      roleFilter: roleFilter == const Object()
          ? this.roleFilter
          : roleFilter as UserRole?,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  bool get hasFilter =>
      search.isNotEmpty || branchId != null || roleFilter != null;
}

/// Paginated result state for one tab.
class UserHubPageState {
  final List<ProfileModel> items;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  const UserHubPageState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  UserHubPageState copyWith({
    List<ProfileModel>? items,
    bool? isLoading,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return UserHubPageState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// =============================================================================
// QUERY STATE NOTIFIER (per tab)
// =============================================================================

class UserHubQueryNotifier extends StateNotifier<UserHubQuery> {
  UserHubQueryNotifier() : super(const UserHubQuery());

  void setSearch(String value) => state = state.copyWith(search: value);
  void setBranch(String? id) => state = state.copyWith(branchId: id);
  void setRole(UserRole? role) => state = state.copyWith(roleFilter: role);
  void setSort(UserSortBy sort) => state = state.copyWith(sortBy: sort);
  void reset() => state = const UserHubQuery();
}

final userHubQueryProvider = StateNotifierProvider.family<UserHubQueryNotifier,
    UserHubQuery, UserHubTab>(
  (ref, tab) => UserHubQueryNotifier(),
);

// =============================================================================
// PAGE STATE NOTIFIER (per tab)
// =============================================================================

class UserHubPageNotifier extends StateNotifier<UserHubPageState> {
  final UserRepository _repo;
  final UserHubTab _tab;
  final UserHubQuery _query;

  static const int _pageSize = 25;

  UserHubPageNotifier(this._repo, this._tab, this._query)
      : super(const UserHubPageState()) {
    loadFirstPage();
  }

  Future<void> loadFirstPage() async {
    state = const UserHubPageState(isLoading: true, hasMore: true);
    await _fetch(0);
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, clearError: true);
    await _fetch(state.items.length);
  }

  Future<void> _fetch(int offset) async {
    try {
      final batch = await _runQuery(offset);
      final merged =
          offset == 0 ? batch : [...state.items, ...batch];
      state = state.copyWith(
        items: merged,
        isLoading: false,
        hasMore: batch.length >= _pageSize,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<List<ProfileModel>> _runQuery(int offset) async {
    switch (_tab) {
      case UserHubTab.team:
        final roles = _query.roleFilter != null
            ? <UserRole>{_query.roleFilter!}
            : <UserRole>{
                UserRole.executiveAdmin,
                UserRole.manager,
                UserRole.collectionAgent,
              };
        return _repo.getProfilesPaginated(
          roles: roles,
          excludeStatuses: const {AccountStatus.suspended, AccountStatus.inactive},
          branchId: _query.branchId,
          search: _query.search,
          sortBy: _query.sortBy,
          offset: offset,
          limit: _pageSize,
        );
      case UserHubTab.customers:
        return _repo.getMembersPaginated(
          branchId: _query.branchId,
          search: _query.search,
          sortBy: _query.sortBy,
          offset: offset,
          limit: _pageSize,
        );
      case UserHubTab.suspended:
        return _repo.getProfilesPaginated(
          includeStatuses: const {
            AccountStatus.suspended,
            AccountStatus.inactive,
          },
          branchId: _query.branchId,
          search: _query.search,
          sortBy: _query.sortBy,
          offset: offset,
          limit: _pageSize,
        );
      case UserHubTab.invites:
        // Invites are handled by their own provider — return empty so this
        // notifier never fires for the invites tab.
        return const [];
    }
  }
}

final userHubPageProvider = StateNotifierProvider.family<UserHubPageNotifier,
    UserHubPageState, UserHubTab>(
  (ref, tab) {
    final repo = ref.watch(userRepositoryProvider);
    final query = ref.watch(userHubQueryProvider(tab));
    return UserHubPageNotifier(repo, tab, query);
  },
);

// =============================================================================
// LEGACY PROVIDERS (still referenced from other features)
// =============================================================================

final userListProvider = FutureProvider<List<ProfileModel>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUsers();
});

final customerListProvider = FutureProvider<List<ProfileModel>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  final allUsers = await repository.getUsers();
  return allUsers.where((u) => u.role == UserRole.customer).toList();
});

final userDetailsProvider =
    FutureProvider.family<ProfileModel?, String>((ref, id) async {
  final users = await ref.watch(userListProvider.future);
  try {
    final profile = users.firstWhere((u) => u.id == id);
    // If the profile is from the `profiles` table and has no linked member
    // ID, the downstream loan/savings filters will fail (they key on the
    // member table's primary key).  Resolve the linked member record so that
    // `memberCode` is populated correctly.
    if (!profile.isMember && profile.memberCode == null) {
      try {
        final client = ref.read(supabaseClientProvider);
        final member = await client
            .from('members')
            .select('*')
            .eq('profile_id', id)
            .maybeSingle();
        if (member != null) {
          return ProfileModel.fromMembersJson(member);
        }
      } catch (_) {}
    }
    return profile;
  } catch (_) {
    // Not found in users list — try fetching directly from members table
    try {
      final client = ref.read(supabaseClientProvider);
      final member = await client
          .from('members')
          .select('*')
          .eq('id', id)
          .maybeSingle();
      if (member != null) {
        return ProfileModel.fromMembersJson(member);
      }
    } catch (_) {}
    // Fallback: try the profiles table
    try {
      final client = ref.read(supabaseClientProvider);
      final row = await client
          .from('profiles')
          .select('*')
          .eq('id', id)
          .maybeSingle();
      if (row != null) {
        return ProfileModel.fromJson(row);
      }
    } catch (_) {}
    return null;
  }
});

final userStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUserStats();
});

// =============================================================================
// LAST ACTIVITY BATCH (per visible page)
// =============================================================================

/// Last activity timestamps for the currently-visible team page.
/// Keyed by `auth.users.id` (i.e. `profile.user_id`).
final lastActivityProvider =
    FutureProvider.family<Map<String, DateTime>, List<String>>(
  (ref, userIds) async {
    if (userIds.isEmpty) return const {};
    final repo = ref.watch(userRepositoryProvider);
    return repo.getLastActivityBatch(userIds);
  },
);

// =============================================================================
// STAFF PERFORMANCE TODAY
// =============================================================================

/// Today's collection total per profile id (collection_agent).
final staffPerformanceTodayProvider =
    FutureProvider.family<Map<String, double>, List<String>>(
  (ref, profileIds) async {
    if (profileIds.isEmpty) return const {};
    final repo = ref.watch(userRepositoryProvider);
    return repo.getStaffPerformanceToday(profileIds);
  },
);

// =============================================================================
// ADMIN ACTIONS NOTIFIER
// =============================================================================

class UserAdminNotifier extends StateNotifier<AsyncValue<void>> {
  final UserRepository _repository;
  final Ref _ref;

  UserAdminNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  void _invalidate() {
    _ref.invalidate(userStatsProvider);
    for (final tab in UserHubTab.values) {
      // Force the StateNotifier to rebuild + reload page 1.
      _ref.invalidate(userHubPageProvider(tab));
      // Explicitly trigger a reload on the new notifier instance
      _ref.read(userHubPageProvider(tab).notifier).loadFirstPage();
    }
  }

  Future<bool> changeRole(String profileId, UserRole role) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateUserRole(profileId, role);
      _invalidate();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> changeStatus(String profileId, AccountStatus status) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateUserStatus(profileId, status);
      _invalidate();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncValue.loading();
    try {
      await _repository.sendPasswordReset(email);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> forceLogout(String profileId, {String? userId}) async {
    state = const AsyncValue.loading();
    try {
      await _repository.forceLogout(profileId, userId: userId);
      _invalidate();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteUsers(List<String> ids) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteUsers(ids);
      _invalidate();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<int> bulkInsertMembers(List<Map<String, dynamic>> rows) async {
    state = const AsyncValue.loading();
    try {
      final n = await _repository.bulkInsertMembers(rows);
      _invalidate();
      state = const AsyncValue.data(null);
      return n;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 0;
    }
  }
}

final userAdminProvider =
    StateNotifierProvider<UserAdminNotifier, AsyncValue<void>>((ref) {
  return UserAdminNotifier(ref.watch(userRepositoryProvider), ref);
});

// =============================================================================
// LEGACY DELETE NOTIFIER (kept for backwards compatibility)
// =============================================================================

class UserListNotifier extends StateNotifier<AsyncValue<List<ProfileModel>>> {
  final UserRepository _repository;
  final Ref _ref;

  UserListNotifier(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    state = const AsyncValue.loading();
    try {
      final users = await _repository.getUsers();
      state = AsyncValue.data(users);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteUsers(List<String> ids) async {
    try {
      await _repository.deleteUsers(ids);
      _ref.invalidate(userListProvider);
      _ref.invalidate(userStatsProvider);
      for (final tab in UserHubTab.values) {
        _ref.invalidate(userHubPageProvider(tab));
        _ref.read(userHubPageProvider(tab).notifier).loadFirstPage();
      }
    } catch (e) {
      rethrow;
    }
  }

  void refresh() {
    _ref.invalidate(userListProvider);
  }
}

final userListNotifierProvider =
    StateNotifierProvider<UserListNotifier, AsyncValue<List<ProfileModel>>>(
        (ref) {
  return UserListNotifier(ref.watch(userRepositoryProvider), ref);
});
