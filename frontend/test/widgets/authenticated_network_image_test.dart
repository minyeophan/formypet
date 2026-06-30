import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/widgets/authenticated_network_image.dart';

void main() {
  setUpAll(() {
    initApiClient('http://example.test', includeAuthInterceptor: false);
  });

  testWidgets('renders authenticated PNG bytes inside the requested size', (
    tester,
  ) async {
    dio.httpClientAdapter = _CannedAdapter((_) async => _bytesResponse(_png));

    await _pump(tester, url: '/image.png');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fallback')), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.getSize(find.byType(AuthenticatedNetworkImage)),
      const Size(72, 48),
    );
  });

  testWidgets('uses fallback when URL is absent', (tester) async {
    await _pump(tester);

    expect(find.byKey(const Key('fallback')), findsOneWidget);
  });

  testWidgets('uses fallback while the image request is loading', (
    tester,
  ) async {
    final response = Completer<ResponseBody>();
    dio.httpClientAdapter = _CannedAdapter((_) => response.future);

    await _pump(tester, url: '/slow.png');

    expect(find.byKey(const Key('fallback')), findsOneWidget);
    response.complete(_bytesResponse(_png));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'uses fallback for request failure, empty bytes, and decode failure',
    (tester) async {
      var index = 0;
      for (final response in [
        ResponseBody.fromString('failed', 500),
        _bytesResponse(const []),
        _bytesResponse(const [1, 2, 3]),
      ]) {
        dio.httpClientAdapter = _CannedAdapter((_) async => response);
        await _pump(tester, url: '/broken-${index++}.png');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('fallback')), findsOneWidget);
      }
    },
  );

  testWidgets('reloads bytes when URL changes', (tester) async {
    final requestedPaths = <String>[];
    dio.httpClientAdapter = _CannedAdapter((options) async {
      requestedPaths.add(options.path);
      return _bytesResponse(_png);
    });

    await _pump(tester, url: '/first.png');
    await tester.pumpAndSettle();
    await _pump(tester, url: '/second.png');
    await tester.pumpAndSettle();

    expect(requestedPaths, ['/first.png', '/second.png']);
  });
}

Future<void> _pump(WidgetTester tester, {String? url}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AuthenticatedNetworkImage(
          url: url,
          width: 72,
          height: 48,
          fit: BoxFit.cover,
          fallback: const ColoredBox(
            key: Key('fallback'),
            color: Colors.orange,
          ),
        ),
      ),
    ),
  );
}

ResponseBody _bytesResponse(List<int> bytes) =>
    ResponseBody.fromBytes(bytes, 200);

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _CannedAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _CannedAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}
