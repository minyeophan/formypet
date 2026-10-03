import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/community/community_constants.dart';

void main() {
  test('UTC server activity is current at the same Korean instant', () {
    final now = DateTime.parse('2026-10-04T00:54:40+09:00');
    expect(
      formatCommunityRelativeTime('2026-10-03T15:54:32Z', now: now),
      '방금 전',
    );
    expect(
      formatCommunityRelativeTime('2026-10-03T15:52:32Z', now: now),
      '2분 전',
    );
  });
}
