import '../core/api_client.dart';
import '../models/notification.dart';

class NotificationService {
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
