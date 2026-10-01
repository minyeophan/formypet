import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/password_policy.dart';

void main() {
  test('new passwords respect byte limit without trimming spaces', () {
    expect(newPasswordError('short'), isNotNull);
    expect(newPasswordError('가' * 24), isNull);
    expect(newPasswordError('가' * 25), isNotNull);
    expect(newPasswordError('abc def '), isNull);
  });
}
