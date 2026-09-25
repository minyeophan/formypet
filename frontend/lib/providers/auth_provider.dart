import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../models/user_profile.dart';
import 'pet_provider.dart';
import 'notification_provider.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../services/foreground_notification_service.dart';
import '../services/reminder_tap_service.dart';
import '../services/wallet_budget_service.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserProfile? profile;
  final String? initializationError;
  final int sessionEpoch;

  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.profile,
    this.initializationError,
    this.sessionEpoch = 0,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserProfile? profile,
    String? initializationError,
    bool clearInitializationError = false,
    int? sessionEpoch,
  }) => AuthState(
    sessionEpoch: sessionEpoch ?? this.sessionEpoch,
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

  Future<void> _completeSignedOut({String? deletedAccountId}) async {
    final operation = _beginOperation();
    ReminderTapService.instance.reset();
    _svc.invalidatePendingAuthentication();
    await PushNotificationService.instance.endSession(disableRemote: false);
    try {
      await ForegroundNotificationService.instance.cancelAll();
    } catch (_) {
      debugPrint('Failed to clear local notifications during sign-out.');
    }
    _notificationNotifier?.resetSession(authenticated: false);
    if (deletedAccountId != null) {
      try {
        await clearTokens();
      } catch (_) {
        debugPrint(
          'Failed to clear credentials after account deletion.',
        );
      }
      try {
        await WalletBudgetService().clearAccount(deletedAccountId);
      } catch (_) {
        debugPrint(
          'Failed to clear local account budget after deletion.',
        );
      }
    }
    try {
      await _petNotifier?.clearForSignedOutUser();
    } catch (error) {
      debugPrint('Failed to clear pet state for signed-out user: $error');
    }
    if (!_isCurrent(operation)) return;
    state = AuthState(
      isLoading: false,
      isAuthenticated: false,
      sessionEpoch: state.sessionEpoch,
    );
  }

  int _beginOperation() {
    ++_operation;
    // Account/login lifetime; token rotation must not advance this epoch.
    state = state.copyWith(
      sessionEpoch: state.sessionEpoch + 1,
      isLoading: true,
    );
    return _operation;
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
    if (!_isCurrent(operation)) return;
    state = AuthState(
      sessionEpoch: state.sessionEpoch,
      isLoading: false,
      isAuthenticated: true,
      profile: profile,
    );
    PushNotificationService.instance.beginSession(profile.id);
    // Push registration must not delay the authenticated UI or make login fail.
    PushNotificationService.instance
        .registerDeviceToken(sessionKey: profile.id)
        .catchError((error) {
          debugPrint('Failed to register FCM device token: $error');
        });
  }

  Future<void> _init() async {
    final operation = _beginOperation();
    _notificationNotifier?.resetSession(authenticated: false);
    try {
      final token = await getAccessToken();
      if (!_isCurrent(operation)) return;
      if (token != null) {
        final profile = await _svc.getProfile();
        await _setAuthenticated(profile, operation);
        return;
      }
      state = AuthState(
        isLoading: false,
        isAuthenticated: false,
        sessionEpoch: state.sessionEpoch,
      );
    } catch (_) {
      // Invalid refresh credentials are cleared by the API interceptor, which
      // invokes _handleAuthExpired and invalidates this operation. Other errors
      // must not destroy a saved session or imply authentication succeeded.
      if (!_isCurrent(operation)) return;
      state = AuthState(
        sessionEpoch: state.sessionEpoch,
        isLoading: false,
        isAuthenticated: false,
        initializationError: '로그인 정보를 확인하지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.',
      );
    }
  }

  Future<void> retryInitialization() async {
    if (state.isLoading) return;
    state = AuthState(
      isLoading: true,
      isAuthenticated: false,
      sessionEpoch: state.sessionEpoch,
    );
    await _init();
  }

  Future<void> login({required String email, required String password}) async {
    final operation = _beginOperation();
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
    final operation = _beginOperation();
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
    final operation = _beginOperation();
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
    final operation = _beginOperation();
    ReminderTapService.instance.reset();
    _svc.invalidatePendingAuthentication();
    final authenticatedState = state;
    state = state.copyWith(isLoading: true);
    try {
      try {
        await PushNotificationService.instance.endSession(disableRemote: true);
      } catch (error) {
        debugPrint('Failed to disable FCM device token: $error');
      }
      if (!_isCurrent(operation)) return;
      await _svc.logout();
    } catch (_) {
      if (!_isCurrent(operation)) return;
      state = authenticatedState.copyWith(
        isLoading: false,
        sessionEpoch: state.sessionEpoch,
      );
      final account = authenticatedState.profile?.id;
      if (authenticatedState.isAuthenticated && account != null) {
        PushNotificationService.instance.beginSession(account);
        PushNotificationService.instance
            .registerDeviceToken(sessionKey: account)
            .catchError((Object _) {
              debugPrint(
                'Failed to restore push registration after logout failure.',
              );
            });
      }
      rethrow;
    }
    if (!_isCurrent(operation)) return;
    await _completeSignedOut();
  }

  Future<bool> deleteAccount({String? password}) async {
    if (!state.isAuthenticated || state.profile == null) {
      throw StateError('Cannot delete an unauthenticated account');
    }
    final previous = state;
    final operation = ++_operation;
    state = state.copyWith(isLoading: true);
    try {
      final accepted = await _svc.deleteAccount(password: password);
      if (!_isCurrent(operation)) return false;
      if (!accepted) {
        state = previous.copyWith(isLoading: false);
        return false;
      }
      await _completeSignedOut(deletedAccountId: previous.profile!.id);
      return true;
    } catch (_) {
      if (_isCurrent(operation)) state = previous.copyWith(isLoading: false);
      rethrow;
    }
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
