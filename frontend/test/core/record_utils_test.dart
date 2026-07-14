import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/record_utils.dart';

void main() {
  test('removed record types are absent from supported and quick types', () {
    const removed = {'bath', 'groom'};

    expect(kQuickTypes.map((type) => type.id), isNot(contains(anyOf(removed))));
    expect(kSupportedTypeIds, isNot(contains(anyOf(removed))));
    expect(kDetailKeysByType.keys, isNot(contains(anyOf(removed))));
  });

  test('default quick ids retain the established four-item order', () {
    expect(kDefaultQuickIds, const ['meal', 'water', 'walk', 'poop']);
  });
}
