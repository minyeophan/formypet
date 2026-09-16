import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import 'support_receipt.dart';

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
    final receivedAt = parseSupportReceiptTime(date);
    if (id is! String || id.trim().isEmpty || receivedAt == null) {
      throw const FormatException('Invalid inquiry receipt');
    }
    return InquiryReceipt(id: id, receivedAt: receivedAt);
  }
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
