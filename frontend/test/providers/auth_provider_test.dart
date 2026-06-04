import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    setAuthExpiredHandler(null);
  });

  test('logout locks loading until service completes then signs out', () async {
    final service = _FakeAuthService()..logoutCompleter = Completer<void>();
    final notifier = AuthNotifier.test(_signedIn, service: service);

    final logout = notifier.logout();

    expect(notifier.state.isLoading, isTrue);
    expect(notifier.state.isAuthenticated, isTrue);

    service.logoutCompleter!.complete();
    await logout;

    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.isAuthenticated, isFalse);
    expect(notifier.state.profile, isNull);
  });

  test(
    'logout restores authenticated state and rethrows service failure',
    () async {
      final notifier = AuthNotifier.test(
        _signedIn,
        service: _FakeAuthService(logoutError: Exception('logout failed')),
      );

      await expectLater(notifier.logout(), throwsException);

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.profile, _profile);
    },
  );

  test('logout still signs out when pet cleanup fails', () async {
    final petNotifier = _FakePetNotifier(clearError: Exception('clear failed'));
    final notifier = AuthNotifier.test(_signedIn, petNotifier: petNotifier);

    await notifier.logout();

    expect(petNotifier.clearCalls, 1);
    expect(notifier.state.isAuthenticated, isFalse);
  });

  test('auth expiration clears pet state and signs out', () async {
    final petNotifier = _FakePetNotifier();
    final notifier = AuthNotifier.test(
      _signedIn,
      petNotifier: petNotifier,
      registerAuthExpiredHandler: true,
    );

    await notifyAuthExpired();

    expect(petNotifier.clearCalls, 1);
    expect(notifier.state.isAuthenticated, isFalse);
  });

  test(
    'stored token validation failure clears pet state and signs out',
    () async {
      FlutterSecureStorage.setMockInitialValues({'access_token': 'expired'});
      final petNotifier = _FakePetNotifier();

      final notifier = AuthNotifier(
        _FakeAuthService(profileError: Exception('expired')),
        petNotifier: petNotifier,
      );
      await _waitUntil(() => !notifier.state.isLoading);

      expect(petNotifier.clearCalls, 1);
      expect(notifier.state.isAuthenticated, isFalse);
    },
  );
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 20 && !predicate(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _profile = UserProfile(
  id: 'user-1',
  email: 'user@example.com',
  nickname: '보호자',
);

const _signedIn = AuthState(
  isLoading: false,
  isAuthenticated: true,
  profile: _profile,
);

class _FakeAuthService extends AuthService {
  final Object? logoutError;
  final Object? profileError;
  Completer<void>? logoutCompleter;

  _FakeAuthService({this.logoutError, this.profileError});

  @override
  Future<void> logout() async {
    if (logoutError != null) throw logoutError!;
    await logoutCompleter?.future;
  }

  @override
  Future<UserProfile> getProfile() async {
    if (profileError != null) throw profileError!;
    return _profile;
  }
}

class _FakePetNotifier extends PetNotifier {
  final Object? clearError;
  int clearCalls = 0;

  _FakePetNotifier({this.clearError}) : super.test(_emptyPetState);

  @override
  Future<void> clearForSignedOutUser() async {
    clearCalls++;
    if (clearError != null) throw clearError!;
  }
}

const _emptyPetState = PetState(
  isLoading: false,
  hasOnboarded: false,
  pets: [],
  records: [],
  routines: [],
  todayRoutineItems: [],
  routineCompletions: {},
  quickTypeIds: [],
);
