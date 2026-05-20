import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../models/user_profile.dart';
import 'pet_provider.dart';
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

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserProfile? profile,
  }) => AuthState(
    isLoading: isLoading ?? this.isLoading,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    profile: profile ?? this.profile,
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _svc;
  final PetNotifier? _petNotifier;

  AuthNotifier(this._svc, {PetNotifier? petNotifier})
    : _petNotifier = petNotifier,
      super(const AuthState(isLoading: true, isAuthenticated: false)) {
    setAuthExpiredHandler(_handleAuthExpired);
    _init();
  }

  AuthNotifier.test(super.initialState)
    : _svc = AuthService(),
      _petNotifier = null;

  Future<void> _handleAuthExpired() async {
    await _petNotifier?.clearForSignedOutUser();
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }

  Future<void> _setAuthenticated(UserProfile profile) async {
    await _petNotifier?.loadForAuthenticatedUser();
    state = AuthState(
      isLoading: false,
      isAuthenticated: true,
      profile: profile,
    );
  }

  Future<void> _init() async {
    final token = await getAccessToken();
    if (token != null) {
      try {
        final profile = await _svc.getProfile();
        await _setAuthenticated(profile);
        return;
      } catch (_) {
        await clearTokens();
        await _petNotifier?.clearForSignedOutUser();
      }
    }
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _svc.login(email: email, password: password);
      await _setAuthenticated(profile);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<bool> loginWithKakao() async {
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _svc.loginWithKakao();
      if (profile == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      await _setAuthenticated(profile);
      return true;
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _svc.register(
        email: email,
        password: password,
        nickname: nickname,
      );
      await _setAuthenticated(profile);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _svc.logout();
    await _petNotifier?.clearForSignedOutUser();
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }
}

final authServiceProvider = Provider<AuthService>((_) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(
    ref.read(authServiceProvider),
    petNotifier: ref.read(petProvider.notifier),
  );
  ref.onDispose(() => setAuthExpiredHandler(null));
  return notifier;
});
