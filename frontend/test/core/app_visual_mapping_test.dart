import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/pet_taxonomy.dart';
import 'package:frontend/core/record_utils.dart';
import 'package:frontend/core/visuals/app_visual_catalog.dart';
import 'package:frontend/core/visuals/app_visual_id.dart';
import 'package:frontend/screens/community/community_constants.dart';
import 'package:frontend/screens/routine/routine_schedule_values.dart';

void main() {
  test('catalog contains every AppVisualId', () {
    expect(appVisualCatalog.keys.toSet(), AppVisualId.values.toSet());
  });

  test('speciesVisualId maps known, legacy, and unknown species', () {
    expect(speciesVisualId('cat'), AppVisualId.petCat);
    expect(speciesVisualId('토끼'), AppVisualId.petSmallAnimal);
    expect(speciesVisualId('unknown'), AppVisualId.petExotic);
  });

  test('recordTypeVisualId maps known and unknown record types', () {
    expect(recordTypeVisualId('meal'), AppVisualId.recordMeal);
    expect(recordTypeVisualId('diary'), AppVisualId.recordDiary);
    expect(recordTypeVisualId('unknown'), AppVisualId.genericUnknown);
  });

  test('scheduleVisualId maps known and unknown schedule categories', () {
    expect(scheduleVisualId('hospital'), AppVisualId.scheduleHospital);
    expect(scheduleVisualId('unknown'), AppVisualId.genericUnknown);
  });

  test('communityVisualId maps known and unknown community categories', () {
    expect(communityVisualId('POPULAR'), AppVisualId.communityPopular);
    expect(communityVisualId('unknown'), AppVisualId.genericUnknown);
  });
}
