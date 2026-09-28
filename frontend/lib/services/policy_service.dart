import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

final policyServiceProvider = Provider<PolicyService>((_) => PolicyService());

class PolicyService {
  Future<Map<String, dynamic>> catalog() async => Map<String, dynamic>.from(
    unwrap(
          await dio.get(
            '/api/v1/public/policies',
            options: Options(extra: {'_skipAuth': true}),
          ),
        )
        as Map,
  );
  Future<Map<String, dynamic>> document(String type, {String? version}) async {
    if (version != null) {
      return Map<String, dynamic>.from(
        unwrap(
              await dio.get(
                '/api/v1/public/policies/${Uri.encodeComponent(type)}/${Uri.encodeComponent(version)}',
                options: Options(extra: {'_skipAuth': true}),
              ),
            )
            as Map,
      );
    }
    final data = await catalog();
    final current = data['currentDocuments'];
    if (current is Map) {
      final document = current[type];
      if (document is Map) return Map<String, dynamic>.from(document);
      throw StateError('정책 전문 게시 준비 중입니다.');
    }
    final docs = (data['documents'] as List)
        .whereType<Map>()
        .where(
          (doc) =>
              doc['type'] == type &&
              !DateTime.parse(
                doc['effectiveAt'] as String,
              ).isAfter(DateTime.now()),
        )
        .toList();
    docs.sort(
      (a, b) =>
          (b['effectiveAt'] as String).compareTo(a['effectiveAt'] as String),
    );
    if (docs.isEmpty) throw StateError('정책 전문 게시 준비 중입니다.');
    return Map<String, dynamic>.from(docs.first);
  }

  Future<Map<String, dynamic>> status() async => Map<String, dynamic>.from(
    unwrap(await dio.get('/api/v1/users/me/policy-status')) as Map,
  );
  Future<void> accept(Map<String, dynamic> acceptance) async {
    await dio.post('/api/v1/users/me/policy-consents', data: acceptance);
  }

  Future<List<dynamic>> history() async =>
      unwrap(await dio.get('/api/v1/users/me/policy-consents')) as List;
  Future<void> openWeb(String type) async {
    if (!{'privacy', 'terms', 'account-deletion.html'}.contains(type)) {
      throw ArgumentError('Unknown policy');
    }
    final url = Uri.parse(
      dio.options.baseUrl,
    ).replace(path: '/$type', query: '', fragment: '');
    if (url.scheme != 'https' || url.host.isEmpty) {
      throw StateError('운영 웹 주소가 아직 설정되지 않았어요.');
    }
    final opened = await const MethodChannel(
      'com.formypet/public_web',
    ).invokeMethod<bool>('open', url.toString());
    if (opened != true) throw StateError('웹페이지를 열지 못했어요.');
  }
}
