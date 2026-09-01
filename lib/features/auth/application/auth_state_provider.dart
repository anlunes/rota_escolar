import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/models/auth_user.dart';
import '../../../../app/core/constants/status_constants.dart';

// ---------------------------------------------------------------------------
// Auth State
// ---------------------------------------------------------------------------

class AuthState {
  final AuthUserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final String? pendingVerificationEmail;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.pendingVerificationEmail,
  });

  bool get isAuthenticated => user != null;
  UserRole? get role => user?.role;

  AuthState copyWith({
    AuthUserModel? user,
    bool? isLoading,
    String? errorMessage,
    String? pendingVerificationEmail,
    bool clearUser = false,
    bool clearError = false,
    bool clearPendingEmail = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingVerificationEmail: clearPendingEmail ? null : (pendingVerificationEmail ?? this.pendingVerificationEmail),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth Notifier — Firebase Auth real com fallback mock
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState()) {
    _checkCurrentUser();
  }

  /// Verifica se há sessão ativa ao iniciar o app.
  Future<void> _checkCurrentUser() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _repository.currentUser();
      if (user != null) {
        state = state.copyWith(isLoading: false, user: user);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('[AuthNotifier] _checkCurrentUser error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.login(email, password);
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String whatsapp,
    required UserRole role,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.register(
        name: name,
        email: email,
        password: password,
        whatsapp: whatsapp,
        role: role,
      );
      // Não autentica — aguarda verificação de email
      state = state.copyWith(
        isLoading: false,
        pendingVerificationEmail: user.email,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearPendingEmail() {
    state = state.copyWith(clearPendingEmail: true);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});
