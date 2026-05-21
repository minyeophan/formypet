import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web index configures mobile viewport for stable Flutter Web metrics', () {
    final indexHtml = File('web/index.html').readAsStringSync();

    expect(indexHtml, contains('name="viewport"'));
    expect(indexHtml, contains('width=device-width'));
    expect(indexHtml, contains('initial-scale=1.0'));
    expect(indexHtml, contains('viewport-fit=cover'));
  });
}
