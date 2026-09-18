import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/api_client.dart';
import '../core/secure_storage.dart';

class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService._();
  static final instance = PushNotificationService._();
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  bool get _available => !kIsWeb && Firebase.apps.isNotEmpty;
  StreamSubscription<String>? _tokenSubscription;
  int _generation = 0;
  String? _sessionKey;
  String? _registeredToken;
  Future<void> _writes = Future.value();
  Future<void>? _registration;
  bool _observing = false;

  bool _current(int generation) => generation == _generation && _sessionKey != null;

  void beginSession(String key) {
    if (_sessionKey == key) return;
    _generation++;
    _sessionKey = key;
    _registration = null;
    final subscription = _tokenSubscription;
    _tokenSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (_available && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  Future<void> _serial(Future<void> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> _delete(String token, Options options) async {
    await dio.delete('/api/v1/notifications/device-tokens', queryParameters: {'token': token}, options: options);
  }

  Future<Options> _credentials() async {
    final credentials = await readCredentials();
    return Options(extra: {
      '_requestAccess': credentials.access,
      '_requestCredentialRevision': credentials.revision,
    });
  }

  Future<void> endSession({required bool disableRemote}) async {
    ++_generation;
    _sessionKey = null;
    _registration = null;
    final subscription = _tokenSubscription;
    _tokenSubscription = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    final registered = _registeredToken;
    _registeredToken = null;
    await subscription?.cancel();
    if (!disableRemote || !_available) return;
    final options = await _credentials();
    final token = registered ?? await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _serial(() => _delete(token, options));
    }
  }

  Future<void> registerDeviceToken({String? sessionKey, bool requestPermission = true}) {
    if (!_available || _sessionKey == null || (sessionKey != null && sessionKey != _sessionKey)) {
      return Future.value();
    }
    if (_registration != null) return _registration!;
    final generation = _generation;
    final pending = _register(generation, requestPermission);
    _registration = pending;
    return pending.whenComplete(() {
      if (_current(generation)) _registration = null;
    });
  }

  Future<void> _register(int generation, bool requestPermission) async {
    final settings = requestPermission
        ? await _messaging.requestPermission(alert: true, badge: true, sound: true)
        : await _messaging.getNotificationSettings();
    if (!_current(generation)) return;
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      final subscription = _tokenSubscription;
      _tokenSubscription = null;
      await subscription?.cancel();
      if (!_current(generation)) return;
      // Android may restart the process when permission is revoked. Recover the
      // existing device token so the server registration is disabled as well.
      final previous = _registeredToken ?? await _messaging.getToken();
      if (previous != null && previous.isNotEmpty && _current(generation)) {
        final options = await _credentials();
        await _serial(() async {
          if (!_current(generation)) return;
          await _delete(previous, options);
          if (_current(generation)) _registeredToken = null;
        });
      }
      return;
    }
    _tokenSubscription ??= _messaging.onTokenRefresh.listen((token) {
      unawaited(_sendToken(token, generation).catchError((Object _) {
        debugPrint('FCM token registration failed; retry on next app resume.');
      }));
    }, onError: (Object _) {
      debugPrint('FCM token refresh stream failed.');
    });
    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty && _current(generation)) {
      await _sendToken(token, generation);
    }
  }

  Future<void> _sendToken(String token, int generation) => _serial(() async {
    if (!_current(generation)) return;
    final options = await _credentials();
    if (!_current(generation)) return;
    final previous = _registeredToken;
    await dio.post('/api/v1/notifications/device-tokens', data: {
      'token': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID',
    }, options: options);
    if (!_current(generation)) return;
    _registeredToken = token;
    if (previous != null && previous != token) {
      final currentOptions = await _credentials();
      if (!_current(generation)) return;
      await _delete(previous, currentOptions);
    }
  });

  Future<void> disableDeviceToken() => endSession(disableRemote: true);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _sessionKey != null) {
      unawaited(registerDeviceToken(requestPermission: false).catchError((Object _) {
        debugPrint('FCM registration refresh failed.');
      }));
    }
  }
}
