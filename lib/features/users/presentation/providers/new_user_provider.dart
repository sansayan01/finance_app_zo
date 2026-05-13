import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';

class NewUserState {
  final String fullName;
  final String email;
  final String mobileNumber;
  final UserRole role;
  final String employeeId;
  final String assignedZone;
  final String password;
  final String aadharNumber;
  final String panNumber;
  final bool isLoading;

  NewUserState({
    this.fullName = '',
    this.email = '',
    this.mobileNumber = '',
    this.role = UserRole.fieldStaff,
    this.employeeId = '',
    this.assignedZone = '',
    this.password = '',
    this.aadharNumber = '',
    this.panNumber = '',
    this.isLoading = false,
  });

  NewUserState copyWith({
    String? fullName,
    String? email,
    String? mobileNumber,
    UserRole? role,
    String? employeeId,
    String? assignedZone,
    String? password,
    String? aadharNumber,
    String? panNumber,
    bool? isLoading,
  }) {
    return NewUserState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      role: role ?? this.role,
      employeeId: employeeId ?? this.employeeId,
      assignedZone: assignedZone ?? this.assignedZone,
      password: password ?? this.password,
      aadharNumber: aadharNumber ?? this.aadharNumber,
      panNumber: panNumber ?? this.panNumber,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return UserRepository(ref.watch(supabaseClientProvider), orgId);
});

class NewUserNotifier extends StateNotifier<NewUserState> {
  final UserRepository _repository;

  NewUserNotifier(this._repository) : super(NewUserState());

  void updateFullName(String value) => state = state.copyWith(fullName: value);
  void updateEmail(String value) => state = state.copyWith(email: value);
  void updateMobileNumber(String value) =>
      state = state.copyWith(mobileNumber: value);
  void updateRole(UserRole role) => state = state.copyWith(role: role);
  void updateEmployeeId(String value) =>
      state = state.copyWith(employeeId: value);
  void updateAssignedZone(String value) =>
      state = state.copyWith(assignedZone: value);
  void updatePassword(String value) => state = state.copyWith(password: value);
  void updateAadharNumber(String value) =>
      state = state.copyWith(aadharNumber: value);
  void updatePanNumber(String value) =>
      state = state.copyWith(panNumber: value);

  Future<void> createUser() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.createUser(
        fullName: state.fullName,
        email: state.email,
        phone: state.mobileNumber,
        role: state.role,
        aadhar: state.aadharNumber,
        pan: state.panNumber,
        employeeId: state.employeeId,
        assignedZone: state.assignedZone,
        password: state.password,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  void reset() => state = NewUserState();
}

final newUserProvider =
    StateNotifierProvider<NewUserNotifier, NewUserState>((ref) {
  return NewUserNotifier(ref.watch(userRepositoryProvider));
});
