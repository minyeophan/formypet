import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../models/user_profile.dart';
import 'pet_provider.dart';
import 'notification_provider.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserProfile? profile;
  final String? initializationError;

  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.profile,
    this.initializationError,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserProfile? profile,
    String? initializationError,
    bool clearInitializationError = false,
  }) => AuthState(
    isLoading: isLoading ?? this.isLoading,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    profile: profile ?? this.profile,
    initializationError: clearInitializationError
        ? null
        : (initializationError ?? this.initializationError),
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _svc;
  final PetNotifier? _petNotifier;
  final NotificationNotifier? _notificationNotifier;
  int _operation = 0;

  AuthNotifier(
    this._svc, {
    PetNotifier? petNotifier,
    NotificationNotifier? notificationNotifier,
  }) : _petNotifier = petNotifier,
       _notificationNotifier = notificationNotifier,
       super(const AuthState(isLoading: true, isAuthenticated: false)) {
    setAuthExpiredHandler(_handleAuthExpired);
    _init();
  }

  AuthNotifier.test(
    super.initialState, {
    AuthService? service,
    PetNotifier? petNotifier,
    NotificationNotifier? notificationNotifier,
    bool registerAuthExpiredHandler = false,
  }) : _svc = service ?? AuthService(),
       _petNotifier = petNotifier,
       _notificationNotifier = notificationNotifier {
    if (registerAuthExpiredHandler) {
      setAuthExpiredHandler(_handleAuthExpired);
    }
  }

  Future<void> _handleAuthExpired() async {
    await _completeSignedOut();
  }

  Future<void> _completeSignedOut() async {
    final operation = ++_operation;
    _svc.invalidatePendingAuthentication();
    _notificationNotifier?.resetSession(authenticated: false);
    try {
      await _petNotifier?.clearForSignedOutUser();
    } catch (error) {
      debugPrint('Failed to clear pet state for signed-out user: $error');
    }
    if (!_isCurrent(operation)) return;
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }

  bool _isCurrent(int operation) => mounted && operation == _operation;

  Future<void> _setAuthenticated(UserProfile profile, int operation) async {
    if (!_isCurrent(operation)) return;
    _notificationNotifier?.resetSession(authenticated: true);
    try {
      await _petNotifier?.loadForAuthenticatedUser();
    } catch (error) {
      // Authentication was validated; screen data has its own retry state.
      debugPrint('Failed to load authenticated pet data: $error');
    }
    if (!_isCurrent(operation)) return;
    try {
      await PushNotificationService.instance.registerDeviceToken();
    } catch (error) {
      debugPrint('Failed to register FCM device token: $error');
    }
    if (!_isCurrent(operation)) return;
    state = AuthState(
      isLoading: false,
      isAuthenticated: true,
      profile: profile,
    );
  }

  Future<void> _init() async {
    final operation = ++_operation;
    _notificationNotifier?.resetSession(authenticated: false);
    try {
      final token = await getAccessToken();
      if (!_isCurrent(operation)) return;
      if (token != null) {
        final profile = await _svc.getProfile();
        await _setAuthenticated(profile, operation);
        return;
      }
      state = const AuthState(isLoading: false, isAuthenticated: false);
    } catch (_) {
      // Invalid refresh credentials are cleared by the API interceptor, which
      // invokes _handleAuthExpired and invalidates this operation. Other errors
      // must not destroy a saved session or imply authentication succeeded.
      if (!_isCurrent(operation)) return;
      state = const AuthState(
        isLoading: false,
        isAuthenticated: false,
        initializationError: '로그인 정보를 확인하지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.',
      );
    }
  }

  Future<void> retryInitialization() async {
    if (state.isLoading) return;
    state = const AuthState(isLoading: true, isAuthenticated: false);
    await _init();
  }

  Future<void> login({required String email, required String password}) async {
    final operation = ++_operation;
    _notificationNotifier?.resetSession(authenticated: false);
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _svc.login(email: email, password: password);
      if (!_isCurrent(operation)) return;
      await _setAuthenticated(profile, operation);
    } catch (_) {
      if (!_isCurrent(operation)) return;
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<bool> loginWithKakao() async {
    final operation = ++_operation;
    _notificationNotifier?.resetSession(authenticated: false);
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _svc.loginWithKakao();
      if (!_isCurrent(operation)) return false;
      if (profile == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      await _setAuthenticated(profile, operation);
      return _isCurrent(operation) && state.isAuthenticated;
    } catch (_) {
      if (!_isCurrent(operation)) return false;
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final operation = ++_operation;
    _notificationNotifier?.resetSession(authenticated: false);
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _svc.register(
        email: email,
        password: password,
        nickname: nickname,
      );
      if (!_isCurrent(operation)) return;
      await _setAuthenticated(profile, operation);
    } catch (_) {
      if (!_isCurrent(operation)) return;
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> updateProfile({required String nickname}) async {
    final operation = _operation;
    final profile = await _svc.updateProfile(nickname: nickname);
    if (!_isCurrent(operation) || !state.isAuthenticated) return;
    state = state.copyWith(profile: profile);
  }

  Future<void> uploadProfileImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final operation = _operation;
    final profile = await _svc.uploadProfileImage(
      bytes: bytes,
      filename: filename,
    );
    if (!_isCurrent(operation) || !state.isAuthenticated) return;
    state = state.copyWith(profile: profile);
  }

  Future<void> logout() async {
    final operation = ++_operation;
    _svc.invalidatePendingAuthentication();
    final authenticatedState = state;
    state = state.copyWith(isLoading: true);
    try {
      try {
        await PushNotificationService.instance.disableDeviceToken();
      } catch (error) {
        debugPrint('Failed to disable FCM device token: $error');
      }
      if (!_isCurrent(operation)) return;
      await _svc.logout();
    } catch (_) {
      if (!_isCurrent(operation)) return;
      state = authenticatedState;
      rethrow;
    }
    if (!_isCurrent(operation)) return;
    await _completeSignedOut();
  }

  @override
  void dispose() {
    _operation++;
    _svc.invalidatePendingAuthentication();
    super.dispose();
  }
}

final authServiceProvider = Provider<AuthService>((_) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(
    ref.read(authServiceProvider),
    petNotifier: ref.read(petProvider.notifier),
    notificationNotifier: ref.read(notificationProvider.notifier),
  );
  ref.onDispose(() => setAuthExpiredHandler(null));
  return notifier;
});
