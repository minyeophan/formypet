import 'visuals/app_visual_id.dart';

export 'pet_taxonomy.dart' show kSpeciesList, speciesLabel;

class RecordType {
  final String id;
  final String label;
  final AppVisualId visualId;

  const RecordType({
    required this.id,
    required this.label,
    required this.visualId,
  });
}

// Quick/routine types keep diary hidden even though the backend stores it.
const List<RecordType> kQuickTypes = [
  RecordType(id: 'meal', label: '급식', visualId: AppVisualId.recordMeal),
  RecordType(id: 'water', label: '음수', visualId: AppVisualId.recordWater),
  RecordType(id: 'walk', label: '산책', visualId: AppVisualId.recordWalk),
  RecordType(id: 'poop', label: '배변', visualId: AppVisualId.recordPoop),
  RecordType(id: 'medicine', label: '투약', visualId: AppVisualId.recordMedicine),
  RecordType(id: 'weight', label: '체중', visualId: AppVisualId.recordWeight),
  RecordType(id: 'vet', label: '병원', visualId: AppVisualId.recordVet),
  RecordType(id: 'bath', label: '목욕', visualId: AppVisualId.recordBath),
  RecordType(id: 'groom', label: '미용', visualId: AppVisualId.recordGroom),
];

const Map<String, String> kRecordTypeFallbackLabels = {
  'diary': '일기',
  'etc': '기타',
};

String recordTypeLabel(String typeId) {
  final quickType = kQuickTypes.where((type) => type.id == typeId).firstOrNull;
  return quickType?.label ?? kRecordTypeFallbackLabels[typeId] ?? typeId;
}

AppVisualId recordTypeVisualId(String typeId) {
  final quickType = kQuickTypes.where((type) => type.id == typeId).firstOrNull;
  if (quickType != null) return quickType.visualId;
  return switch (typeId) {
    'diary' => AppVisualId.recordDiary,
    'etc' => AppVisualId.recordEtc,
    _ => AppVisualId.genericUnknown,
  };
}

// Backend-supported types for quick record API calls; diary is intentionally excluded.
const Set<String> kSupportedTypeIds = {
  'meal',
  'water',
  'walk',
  'poop',
  'medicine',
  'weight',
  'vet',
};

const List<String> kDefaultQuickIds = [
  'meal',
  'water',
  'walk',
  'poop',
];

// Detail field keys per record type — mirrors DETAIL_KEYS_BY_TYPE in RN
const Map<String, List<String>> kDetailKeysByType = {
  'meal': ['foodName', 'amount', 'unit', 'consumeMode'],
  'water': ['amount', 'unit'],
  'walk': ['duration', 'distance', 'startLng', 'startLat', 'endLng', 'endLat'],
  'poop': ['consistency', 'color', 'hasBlood'],
  'medicine': ['medicineName', 'dosage', 'unit'],
  'weight': ['value', 'unit'],
  'vet': ['clinicName', 'diagnosis', 'vetCost', 'clinicLng', 'clinicLat'],
  'bath': ['shampoo'],
  'groom': ['groomType'],
};

// Strip null/empty detail fields before API send
Map<String, dynamic> sanitizeDetail(
  Map<String, dynamic> detail,
  String typeId,
) {
  final keys = kDetailKeysByType[typeId] ?? [];
  final result = <String, dynamic>{};
  for (final k in keys) {
    if (k == 'consumeMode') continue; // UI-only field
    final v = detail[k];
    if (v != null && v.toString().isNotEmpty) {
      result[k] = v;
    }
  }
  // meal: keep only the consumed field based on consumeMode
  if (typeId == 'meal') {
    final mode = detail['consumeMode'] ?? 'direct';
    if (mode == 'percent') {
      result.remove('amount');
    } else {
      result.remove('consumePercent');
    }
  }
  return result;
}

Map<String, dynamic> emptyDetail(String typeId) {
  final keys = kDetailKeysByType[typeId] ?? [];
  return {for (final k in keys) k: null};
}
