import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import 'new_user_provider.dart';

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
    return users.firstWhere((u) => u.id == id);
  } catch (e) {
    return null;
  }
});

final userStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUserStats();
});

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
