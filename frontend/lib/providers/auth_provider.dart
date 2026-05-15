import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/secure_storage.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserProfile? profile;

  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.profile,
  });

  AuthState copyWith({bool? isLoading, bool? isAuthenticated, UserProfile? profile}) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        profile: profile ?? this.profile,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _svc;

  AuthNotifier(this._svc)
      : super(const AuthState(isLoading: true, isAuthenticated: false)) {
    _init();
  }

  Future<void> _init() async {
    final token = await getAccessToken();
    if (token != null) {
      try {
        final profile = await _svc.getProfile();
        state = AuthState(isLoading: false, isAuthenticated: true, profile: profile);
        return;
      } catch (_) {}
    }
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }

  Future<void> login({required String email, required String password}) async {
    final profile = await _svc.login(email: email, password: password);
    state = AuthState(isLoading: false, isAuthenticated: true, profile: profile);
  }

  Future<void> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final profile = await _svc.register(
        email: email, password: password, nickname: nickname);
    state = AuthState(isLoading: false, isAuthenticated: true, profile: profile);
  }

  Future<void> logout() async {
    await _svc.logout();
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }
}

final authServiceProvider = Provider<AuthService>((_) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});
