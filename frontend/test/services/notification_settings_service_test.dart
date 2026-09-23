import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/secure_storage.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/notification_service.dart';
import '../support/audit_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => initApiClient('https://example.test', includeAuthInterceptor: false),
  );
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    setAuthExpiredHandler(null);
  });
  test(
    'settings are loaded and saved through the existing account API',
    () async {
      final api = AuditApi((r) => {'enabled': r.method == 'GET'});
      useAuditApi(api);
      final dynamic service = NotificationService();
      expect(await service.getSettings(), isTrue);
      expect(await service.updateSettings(false), isFalse);
      expect(api.requests.map((r) => r.path).toSet(), {
        '/api/v1/notifications/settings',
      });
      expect(api.requests.last.method, 'PATCH');
      expect(api.requests.last.data, {'enabled': false});
    },
  );
  test('malformed settings are not interpreted as disabled', () async {
    useAuditApi(AuditApi((r) => {'enabled': 'false'}));
    final dynamic service = NotificationService();
    await expectLater(service.getSettings(), throwsFormatException);
  });
  test('queued settings write never borrows a new login credential', () async {
    final api = AuditApi((r) => {'enabled': false});
    useAuditApi(api);
    await saveTokens(access: 'account-a', refresh: 'refresh-a');
    final write = NotificationService().updateSettings(false);
    final login = saveTokens(access: 'account-b', refresh: 'refresh-b');
    await expectLater(write, throwsStateError);
    await login;
    expect(api.requests, isEmpty);
  });
  test(
    'login intent advances epoch before completion; refresh does not',
    () async {
      final service = LoginService();
      final auth = AuthNotifier.test(
        const AuthState(isLoading: false, isAuthenticated: false),
        service: service,
      );
      addTearDown(auth.dispose);
      final dynamic before = auth.state;
      final int epoch = before.sessionEpoch;
      final login = auth.login(email: 'test@example.test', password: 'test');
      final dynamic during = auth.state;
      expect(during.sessionEpoch, greaterThan(epoch));
      service.pending.complete(
        const UserProfile(
          id: '1',
          email: 'test@example.test',
          nickname: 'test',
        ),
      );
      await login;
      final dynamic signedIn = auth.state;
      final int signedInEpoch = signedIn.sessionEpoch;
      await saveTokens(access: 'test', refresh: 'test-refresh');
      await replaceTokensIfCurrent(
        expectedRevision: credentialRevision,
        access: 'renewed',
        refresh: 'renewed-refresh',
      );
      final dynamic refreshed = auth.state;
      expect(refreshed.sessionEpoch, signedInEpoch);
      await auth.logout();
      final dynamic signedOut = auth.state;
      expect(signedOut.sessionEpoch, greaterThan(signedInEpoch));
    },
  );
}

class LoginService extends AuthService {
  final pending = Completer<UserProfile>();
  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) => pending.future;
  @override
  Future<void> logout() async {}
}
