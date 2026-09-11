import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

class ReportReceipt {
  const ReportReceipt({required this.id, required this.receivedAt});
  final String id;
  final DateTime receivedAt;
}

class BlockedUser {
  const BlockedUser({required this.userId, required this.nickname});
  final String userId;
  final String nickname;
}

String newReportRequestId() => base64UrlEncode(
  List<int>.generate(16, (_) => Random.secure().nextInt(256)),
).replaceAll('=', '');

class CommunitySafetyService {
  Future<ReportReceipt> reportPost({
    required String postId,
    required String reason,
    required String detail,
    required String requestId,
  }) async {
    final response = await dio.post(
      '/api/v1/posts/${Uri.encodeComponent(postId)}/reports',
      data: {'reason': reason, 'detail': detail.trim(), 'requestId': requestId},
    );
    final data = unwrap(response) as Map<String, dynamic>;
    final id = data['id']?.toString();
    final receivedAt = DateTime.tryParse(data['receivedAt']?.toString() ?? '');
    if (id == null || id.isEmpty || receivedAt == null) {
      throw const FormatException('Missing report receipt');
    }
    return ReportReceipt(id: id, receivedAt: receivedAt);
  }

  Future<List<BlockedUser>> getBlockedUsers() async {
    final response = await dio.get('/api/v1/users/me/blocks');
    final data = unwrap(response) as Map<String, dynamic>;
    return (data['items'] as List).map((value) {
      final item = value as Map<String, dynamic>;
      final id = item['userId']?.toString();
      if (id == null || id.isEmpty) {
        throw const FormatException('Missing blocked user');
      }
      final nickname = (item['nickname'] as String?)?.trim();
      return BlockedUser(
        userId: id,
        nickname: nickname == null || nickname.isEmpty ? '익명집사' : nickname,
      );
    }).toList();
  }

  Future<void> block(String userId) async {
    _checkMutation(
      await dio.put('/api/v1/users/me/blocks/${Uri.encodeComponent(userId)}'),
    );
  }

  Future<void> unblock(String userId) async {
    _checkMutation(
      await dio.delete(
        '/api/v1/users/me/blocks/${Uri.encodeComponent(userId)}',
      ),
    );
  }

  void _checkMutation(Response response) {
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw const FormatException('Block operation not confirmed');
    }
  }
}

final communitySafetyServiceProvider = Provider<CommunitySafetyService>(
  (ref) => CommunitySafetyService(),
);

String reportErrorMessage(Object error) {
  final status = error is DioException ? error.response?.statusCode : null;
  return switch (status) {
    401 => '로그인 상태를 확인한 후 다시 시도해 주세요.',
    403 => '이 게시글을 신고할 수 없어요.',
    404 => '게시글을 찾을 수 없거나 신고 기능을 이용할 수 없어요.',
    409 => '이미 접수한 신고이거나 요청이 충돌했어요. 접수 내용을 확인해 주세요.',
    _ => '접수하지 못했어요. 입력 내용은 그대로예요. 다시 시도해 주세요.',
  };
}
