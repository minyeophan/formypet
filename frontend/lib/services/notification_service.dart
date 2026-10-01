import 'package:dio/dio.dart';
import '../core/secure_storage.dart';
import '../core/api_client.dart';
import '../models/notification.dart';

class NotificationService {
  Future<bool> getSettings() async {
    final options = await _settingsCredentials();
    final res = await dio.get(
      '/api/v1/notifications/settings',
      options: options,
    );
    return _enabled(unwrap(res));
  }

  Future<bool> updateSettings(bool enabled) async {
    final options = await _settingsCredentials();
    final res = await dio.patch(
      '/api/v1/notifications/settings',
      data: {'enabled': enabled},
      options: options,
    );
    return _enabled(unwrap(res));
  }

  Future<Options> _settingsCredentials() async {
    final revision = credentialRevision;
    final credentials = await readCredentials();
    if (credentials.revision != revision || credentialRevision != revision) {
      throw StateError('Authentication credentials changed');
    }
    // The auth interceptor rejects this request if another login replaces
    // credentials before dispatch; its usual 401 refresh still works.
    return Options(
      extra: {
        '_requestAccess': credentials.access,
        '_requestCredentialRevision': credentials.revision,
      },
    );
  }

  bool _enabled(Object? data) {
    if (data is! Map || data['enabled'] is! bool) {
      throw const FormatException('Invalid notification settings');
    }
    return data['enabled'] as bool;
  }

  Future<NotificationFeed> list({String? cursor, int limit = 20}) async {
    final res = await dio.get(
      '/api/v1/notifications',
      queryParameters: {'cursor': cursor, 'limit': limit},
    );
    return NotificationFeed.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<void> markRead(String id) async {
    await dio.patch('/api/v1/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await dio.post('/api/v1/notifications/read-all');
  }
}
