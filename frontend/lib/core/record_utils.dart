import 'package:flutter/material.dart';

export 'pet_taxonomy.dart' show kSpeciesList, speciesLabel;

class RecordType {
  final String id;
  final String label;
  final IconData icon;

  const RecordType({required this.id, required this.label, required this.icon});
}

// Quick/routine types keep diary hidden even though the backend stores it.
const List<RecordType> kQuickTypes = [
  RecordType(id: 'meal', label: '급식', icon: Icons.restaurant),
  RecordType(id: 'water', label: '음수', icon: Icons.water_drop),
  RecordType(id: 'walk', label: '산책', icon: Icons.directions_walk),
  RecordType(id: 'poop', label: '배변', icon: Icons.pets),
  RecordType(id: 'play', label: '놀이', icon: Icons.sports_esports),
  RecordType(id: 'sleep', label: '수면', icon: Icons.bedtime),
  RecordType(id: 'medicine', label: '투약', icon: Icons.medication),
  RecordType(id: 'weight', label: '체중', icon: Icons.monitor_weight),
  RecordType(id: 'vet', label: '병원', icon: Icons.local_hospital),
  RecordType(id: 'checkup', label: '검진', icon: Icons.health_and_safety),
  RecordType(id: 'bath', label: '목욕', icon: Icons.bathtub),
  RecordType(id: 'groom', label: '미용', icon: Icons.content_cut),
];

const Map<String, String> kRecordTypeFallbackLabels = {
  'diary': '일기',
  'etc': '기타',
};

const Map<String, IconData> kRecordTypeFallbackIcons = {
  'diary': Icons.edit_note,
  'etc': Icons.more_horiz,
};

String recordTypeLabel(String typeId) {
  final quickType = kQuickTypes.where((type) => type.id == typeId).firstOrNull;
  return quickType?.label ?? kRecordTypeFallbackLabels[typeId] ?? typeId;
}

IconData recordTypeIcon(String typeId) {
  final quickType = kQuickTypes.where((type) => type.id == typeId).firstOrNull;
  return quickType?.icon ?? kRecordTypeFallbackIcons[typeId] ?? Icons.circle;
}

// Backend-supported types for quick record API calls; diary is intentionally excluded.
const Set<String> kSupportedTypeIds = {
  'meal',
  'water',
  'walk',
  'poop',
  'play',
  'sleep',
  'medicine',
  'weight',
  'vet',
  'checkup',
};

const List<String> kDefaultQuickIds = [
  'meal',
  'water',
  'walk',
  'poop',
  'play',
  'sleep',
];

// Detail field keys per record type — mirrors DETAIL_KEYS_BY_TYPE in RN
const Map<String, List<String>> kDetailKeysByType = {
  'meal': ['foodName', 'amount', 'unit', 'consumeMode'],
  'water': ['amount', 'unit'],
  'walk': ['duration', 'distance', 'startLng', 'startLat', 'endLng', 'endLat'],
  'poop': ['consistency', 'color', 'hasBlood'],
  'play': ['duration', 'activity'],
  'sleep': ['duration'],
  'medicine': ['medicineName', 'dosage', 'unit'],
  'weight': ['value', 'unit'],
  'vet': ['clinicName', 'diagnosis', 'vetCost', 'clinicLng', 'clinicLat'],
  'checkup': ['items'],
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
