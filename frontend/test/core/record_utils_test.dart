import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/record_utils.dart';

void main() {
  test('deprecated record types are absent from supported and quick types', () {
    const deprecated = {'play', 'sleep', 'checkup', 'bath', 'groom'};

    expect(kQuickTypes.map((type) => type.id), isNot(contains(anyOf(deprecated))));
    expect(kSupportedTypeIds, isNot(contains(anyOf(deprecated))));
    expect(kDetailKeysByType.keys, isNot(contains(anyOf(deprecated))));
  });

  test('default quick ids retain the established four-item order', () {
    expect(kDefaultQuickIds, const ['meal', 'water', 'walk', 'poop']);
  });
}
