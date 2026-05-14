import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';
import '../../../settings/data/providers/activity_log_repository_provider.dart';

final Provider<AuthRepository?> authRepositoryProvider = Provider<AuthRepository?>((ref) {
  try {
    final client = Supabase.instance.client;
    final logRepo = ref.read(activityLogRepositoryProvider);
    return AuthRepository(client, logRepo);
  } catch (e) {
    // Return null if Supabase not initialized - demo mode
    return null;
  }
});

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
  emailVerification,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository? _repository;

  AuthNotifier(this._repository) : super(const AuthState()) {
    _checkSession();
  }

  Future<void> _checkSession() async {
    if (_repository == null) return;

    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        // Biometric check
        final prefs = await SharedPreferences.getInstance();
        final biometricEnabled = prefs.getBool('biometricAuth') ?? false;

        if (biometricEnabled) {
          final LocalAuthentication auth = LocalAuthentication();
          final bool canAuthenticateWithBiometrics =
              await auth.canCheckBiometrics;
          final bool canAuthenticate =
              canAuthenticateWithBiometrics || await auth.isDeviceSupported();

          if (canAuthenticate) {
            try {
              final bool didAuthenticate = await auth.authenticate(
                localizedReason: 'Please authenticate to access MicroFlow Pro',
                persistAcrossBackgrounding: true,
                biometricOnly: false,
              );

              if (!didAuthenticate) {
                await _repository.signOut();
                state = state.copyWith(status: AuthStatus.unauthenticated);
                return;
              }
            } on PlatformException catch (_) {
              await _repository.signOut();
              state = state.copyWith(status: AuthStatus.unauthenticated);
              return;
            }
          }
        }

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    if (_repository == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage:
            'Supabase not configured. Please add your Supabase credentials.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? orgName,
  }) async {
    if (_repository == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage:
            'Supabase not configured. Please add your Supabase credentials.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        orgName: orgName,
      );
      // If no orgId, email verification is needed
      if (user.orgId == null) {
        state = state.copyWith(
          status: AuthStatus.emailVerification,
          user: user,
          errorMessage: 'Please check your email to verify your account.',
        );
        return true;
      }
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    if (_repository == null) return;
    await _repository.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // Exposed for setup wizard to refresh user after org creation
  Future<void> refreshCurrentUser() async {
    if (_repository == null) return;
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<bool> resetPassword(String email) async {
    if (_repository == null) return false;
    try {
      await _repository.resetPassword(email);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    String? phone,
    String? email,
    String? address,
    String? pan,
    String? aadhar,
    String? employeeId,
    String? assignedZone,
  }) async {
    if (_repository == null) return false;
    try {
      await _repository.updateProfile(
        fullName: fullName,
        phone: phone,
        email: email,
        address: address,
        pan: pan,
        aadhar: aadhar,
        employeeId: employeeId,
        assignedZone: assignedZone,
      );
      await _checkSession();
      return true;
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: _getErrorMessage(e));
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_repository == null) return false;
    try {
      // Verify current password first
      await _repository.verifyPassword(currentPassword);
      // Update to new password
      await _repository.updatePassword(newPassword);
      return true;
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMessage: _getErrorMessage(e));
      return false;
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is AuthException) {
      return error.message;
    }

    final message = error.toString().toLowerCase();
    if (message.contains('invalid credentials') ||
        message.contains('invalid login credentials')) {
      return 'Invalid email or password';
    }
    if (message.contains('user already registered')) {
      return 'This email is already registered';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email address';
    }
    if (message.contains('network') || message.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    }

    // Return the actual error message if possible to help debugging
    if (error is Exception) {
      final str = error.toString();
      if (str.startsWith('Exception: ')) {
        return str.substring(11);
      }
      return str;
    }

    return 'An error occurred: ${error.toString()}';
  }
}

final StateNotifierProvider<AuthNotifier, AuthState> authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.status == AuthStatus.authenticated;
});

final Provider<UserModel?> currentUserProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user;
});
