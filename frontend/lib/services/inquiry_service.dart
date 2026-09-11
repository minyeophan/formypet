import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

const inquiryTypes = {
  'ACCOUNT': '계정/로그인',
  'RECORD_ROUTINE': '기록/루틴',
  'COMMUNITY': '커뮤니티',
  'BUG': '오류 신고',
  'OTHER': '기타',
};

class InquiryDraft {
  InquiryDraft({
    required this.type,
    required String replyEmail,
    required String title,
    required String body,
  }) : replyEmail = replyEmail.trim(),
       title = title.trim(),
       body = body.trim();
  final String type;
  final String replyEmail;
  final String title;
  final String body;
  Map<String, String> toJson() => {
    'type': type,
    'replyEmail': replyEmail,
    'title': title,
    'body': body,
  };
  String get fingerprint => jsonEncode(toJson());
}

class InquiryReceipt {
  const InquiryReceipt({required this.id, required this.receivedAt});
  final String id;
  final DateTime receivedAt;
}

String newInquiryRequestId() {
  final random = Random.secure();
  return base64UrlEncode(
    List.generate(16, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
}

class InquiryService {
  Future<InquiryReceipt> submit(
    InquiryDraft draft, {
    required String requestId,
  }) async {
    final response = await dio.post(
      '/api/v1/inquiries',
      data: {...draft.toJson(), 'requestId': requestId},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const FormatException('Inquiry receipt is not confirmed');
    }
    final data = unwrap(response);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing inquiry receipt');
    }
    final id = data['id'];
    final date = data['receivedAt'];
    final receivedAt = _parseReceiptTime(date);
    if (id is! String || id.trim().isEmpty || receivedAt == null) {
      throw const FormatException('Invalid inquiry receipt');
    }
    return InquiryReceipt(id: id, receivedAt: receivedAt);
  }
}

DateTime? _parseReceiptTime(Object? value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-](\d{2}):(\d{2}))$',
  ).firstMatch(value);
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final local = DateTime.utc(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  );
  // DateTime.parse normalizes impossible dates rather than rejecting them.
  final actual = [
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
  ];
  for (var i = 0; i < parts.length; i++) {
    if (parts[i] != actual[i]) return null;
  }
  if (match.group(7) != null &&
      (int.parse(match.group(7)!) > 23 || int.parse(match.group(8)!) > 59)) {
    return null;
  }
  return DateTime.tryParse(value);
}

final inquiryServiceProvider = Provider<InquiryService>(
  (ref) => InquiryService(),
);

String inquiryErrorMessage(Object error) {
  final status = error is DioException ? error.response?.statusCode : null;
  return switch (status) {
    401 => '로그인 상태를 확인한 후 다시 시도해 주세요.',
    403 => '문의를 접수할 수 없어요. 계정 상태를 확인해 주세요.',
    404 => '현재 문의 접수 기능을 이용할 수 없어요. 잠시 후 다시 시도해 주세요.',
    409 => '요청이 충돌했어요. 잠시 후 다시 시도해 주세요.',
    _ => '작성 내용은 그대로예요. 다시 시도해 주세요.',
  };
}
