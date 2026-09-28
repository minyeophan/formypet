import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

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
import '../services/policy_service.dart';
import '../services/account_deletion_cleanup.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserProfile? profile;
  final String? initializationError;
  final int sessionEpoch;
  final bool policyAcceptanceRequired;

  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.profile,
    this.initializationError,
    this.sessionEpoch = 0,
    this.policyAcceptanceRequired = false,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserProfile? profile,
    String? initializationError,
    bool clearInitializationError = false,
    int? sessionEpoch,
    bool? policyAcceptanceRequired,
  }) => AuthState(
    sessionEpoch: sessionEpoch ?? this.sessionEpoch,
    policyAcceptanceRequired:
        policyAcceptanceRequired ?? this.policyAcceptanceRequired,
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
  final PolicyService? _policyService;
  final AccountDeletionCleanup _deletionCleanup;
  int _operation = 0;

  AuthNotifier(
    this._svc, {
    PetNotifier? petNotifier,
    NotificationNotifier? notificationNotifier,
  }) : _petNotifier = petNotifier,
       _policyService = PolicyService(),
       _deletionCleanup = AccountDeletionCleanup.instance,
       _notificationNotifier = notificationNotifier,
       super(const AuthState(isLoading: true, isAuthenticated: false)) {
    setAuthExpiredHandler(_handleAuthExpired);
    setPolicyRequiredHandler(_handlePolicyRequired);
    _init();
  }

  AuthNotifier.test(
    super.initialState, {
    AuthService? service,
    PetNotifier? petNotifier,
    NotificationNotifier? notificationNotifier,
    bool registerAuthExpiredHandler = false,
    PolicyService? policyService,
    AccountDeletionCleanup? deletionCleanup,
  }) : _svc = service ?? AuthService(),
       _policyService = policyService,
       _deletionCleanup =
           deletionCleanup ??
           AccountDeletionCleanup(
             actions: {
               'credentials': (_) => clearTokens(),
               'budget': (id) => WalletBudgetService().clearAccount(id),
             },
           ),
       _petNotifier = petNotifier,
       _notificationNotifier = notificationNotifier {
    if (registerAuthExpiredHandler) {
      setAuthExpiredHandler(_handleAuthExpired);
    }
  }

  Future<void> _handleAuthExpired() async {
    await _completeSignedOut();
  }

  Future<void> _handlePolicyRequired() async {
    if (!mounted || !state.isAuthenticated || state.policyAcceptanceRequired) {
      return;
    }
    final profile = state.profile;
    final operation = _beginOperation();
    state = AuthState(
      isLoading: false,
      isAuthenticated: true,
      profile: profile,
      policyAcceptanceRequired: true,
      sessionEpoch: state.sessionEpoch,
    );
    ReminderTapService.instance.reset();
    _notificationNotifier?.resetSession(authenticated: false);
    try {
      await PushNotificationService.instance.endSession(disableRemote: false);
    } catch (_) {}
    if (!_isCurrent(operation)) return;
    try {
      await _petNotifier?.clearForSignedOutUser();
    } catch (_) {}
  }

  Future<bool> _completeSignedOut({String? deletedAccountId}) async {
    final operation = _beginOperation();
    ReminderTapService.instance.reset();
    _svc.invalidatePendingAuthentication();
    var cleanupComplete = true;
    if (deletedAccountId != null) {
      // Queue cleanup before any plugin await. New token acceptance waits on this
      // same queue, so a delayed cleanup cannot erase the next account's tokens.
      cleanupComplete = await _deletionCleanup.run(deletedAccountId);
    } else {
      try {
        await PushNotificationService.instance.endSession(disableRemote: false);
      } catch (_) {
        debugPrint('Failed to end push session during sign-out.');
      }
      if (!_isCurrent(operation)) return false;
      try {
        await ForegroundNotificationService.instance.cancelAll();
      } catch (_) {
        debugPrint('Failed to clear local notifications during sign-out.');
      }
    }
    if (!_isCurrent(operation)) return false;
    _notificationNotifier?.resetSession(authenticated: false);
    try {
      await _petNotifier?.clearForSignedOutUser();
    } catch (error) {
      debugPrint('Failed to clear pet state for signed-out user: $error');
    }
    if (!_isCurrent(operation)) return false;
    state = AuthState(
      isLoading: false,
      isAuthenticated: false,
      sessionEpoch: state.sessionEpoch,
      initializationError: cleanupComplete
          ? null
          : '탈퇴 요청은 접수됐지만 기기 내 데이터 정리가 남아 있어요. 다시 시도해 주세요.',
    );
    return true;
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
    final policyStatus = await _policyService?.status();
    if (!_isCurrent(operation)) return;
    if (policyStatus?['acceptanceRequired'] == true) {
      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        profile: profile,
        policyAcceptanceRequired: true,
        sessionEpoch: state.sessionEpoch,
      );
      return;
    }
    _notificationNotifier?.resetSession(authenticated: true);
    try {
      await _petNotifier?.loadForAuthenticatedUser();
    } catch (error) {
      // Authentication was validated; screen data has its own retry state.
      debugPrint('Failed to load authenticated pet data: $error');
    }
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
      if (!await _deletionCleanup.retryPending()) {
        if (_isCurrent(operation)) {
          state = AuthState(
            isLoading: false,
            isAuthenticated: false,
            sessionEpoch: state.sessionEpoch,
            initializationError: '이전 계정의 기기 내 데이터 정리를 완료하지 못했어요. 다시 시도해 주세요.',
          );
        }
        return;
      }
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

  Future<bool> loginWithKakao({
    Future<Map<String, dynamic>?> Function()? requestConsent,
  }) async {
    final operation = _beginOperation();
    _notificationNotifier?.resetSession(authenticated: false);
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _svc.loginWithKakao(requestConsent: requestConsent);
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
    Map<String, dynamic>? policyAcceptance,
  }) async {
    final operation = _beginOperation();
    _notificationNotifier?.resetSession(authenticated: false);
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _svc.register(
        email: email,
        password: password,
        nickname: nickname,
        policyAcceptance: policyAcceptance,
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
    var dispatched = false;
    try {
      if (!await _deletionCleanup.prepare(previous.profile!.id)) {
        throw StateError('기기 내 정리 정보를 저장하지 못했어요. 탈퇴 요청을 보내지 않았습니다.');
      }
      if (!_isCurrent(operation)) return false;
      dispatched = true;
      final accepted = await _svc.deleteAccount(password: password);
      if (!_isCurrent(operation)) return false;
      if (!accepted) {
        await _deletionCleanup.cancel(previous.profile!.id);
        state = previous.copyWith(isLoading: false);
        return false;
      }
      await _completeSignedOut(deletedAccountId: previous.profile!.id);
      return true;
    } catch (error) {
      final status = error is DioException ? error.response?.statusCode : null;
      final definitiveRejection =
          status != null && status >= 400 && status < 500 && status != 408;
      if (dispatched && !definitiveRejection) {
        if (!_isCurrent(operation)) rethrow;
        // A timeout or server error cannot prove whether the deletion committed.
        // Local cleanup is safe even if the remote outcome is unknown; it is not proof of deletion.
        final signedOut = await _completeSignedOut(
          deletedAccountId: previous.profile!.id,
        );
        if (!signedOut) rethrow;
        state = AuthState(
          isLoading: false,
          isAuthenticated: false,
          sessionEpoch: state.sessionEpoch,
          initializationError:
              '탈퇴 결과를 확인하지 못했어요. 재로그인 또는 문의로 계정 상태를 확인해 주세요. 로그인 실패만으로 탈퇴 완료를 판단할 수 없습니다.',
        );
        rethrow;
      }
      await _deletionCleanup.cancel(previous.profile!.id);
      if (_isCurrent(operation)) state = previous.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> acceptPolicies(Map<String, dynamic> acceptance) async {
    final operation = _operation;
    final profile = state.profile;
    if (profile == null || !state.isAuthenticated) {
      throw StateError('로그인이 필요해요.');
    }
    await _policyService?.accept(acceptance);
    if (!_isCurrent(operation) ||
        !state.isAuthenticated ||
        state.profile?.id != profile.id) {
      return;
    }
    try {
      await _setAuthenticated(profile, operation);
    } catch (_) {
      if (_isCurrent(operation)) state = state.copyWith(isLoading: false);
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
  ref.onDispose(() {
    setAuthExpiredHandler(null);
    setPolicyRequiredHandler(null);
  });
  return notifier;
});
