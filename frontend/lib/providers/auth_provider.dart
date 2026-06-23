import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
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

  AuthNotifier.test(
    super.initialState, {
    AuthService? service,
    PetNotifier? petNotifier,
    bool registerAuthExpiredHandler = false,
  }) : _svc = service ?? AuthService(),
       _petNotifier = petNotifier {
    if (registerAuthExpiredHandler) {
      setAuthExpiredHandler(_handleAuthExpired);
    }
  }

  Future<void> _handleAuthExpired() async {
    await _completeSignedOut();
  }

  Future<void> _completeSignedOut() async {
    try {
      await _petNotifier?.clearForSignedOutUser();
    } catch (error) {
      debugPrint('Failed to clear pet state for signed-out user: $error');
    }
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
        await _completeSignedOut();
        return;
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

  Future<void> updateProfile({required String nickname}) async {
    final profile = await _svc.updateProfile(nickname: nickname);
    state = state.copyWith(profile: profile);
  }

  Future<void> uploadProfileImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final profile = await _svc.uploadProfileImage(
      bytes: bytes,
      filename: filename,
    );
    state = state.copyWith(profile: profile);
  }

  Future<void> logout() async {
    final authenticatedState = state;
    state = state.copyWith(isLoading: true);
    try {
      await _svc.logout();
    } catch (_) {
      state = authenticatedState;
      rethrow;
    }
    await _completeSignedOut();
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
