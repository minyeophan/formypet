import 'package:intl/intl.dart';

import '../../models/activity_record.dart';

const supportedRecordDetailTypeIds = {
  'meal',
  'water',
  'poop',
  'walk',
  'medicine',
  'vet',
  'weight',
  'diary',
  'etc',
};

bool isRecordDetailSupported(String typeId) {
  return supportedRecordDetailTypeIds.contains(typeId);
}

String recordTypeLabel(String typeId) {
  return switch (typeId) {
    'meal' => '급식',
    'water' => '음수',
    'poop' => '배변',
    'walk' => '산책',
    'medicine' => '영양/약',
    'vet' => '병원',
    'weight' => '몸무게',
    'diary' => '일기',
    'etc' => '기타',
    _ => typeId,
  };
}

String recordListSummary(ActivityRecord record) {
  final detail = record.detail;
  switch (record.typeId) {
    case 'meal':
      return mealFoodTypeLabel(detail['foodType']);
    case 'water':
      final amount = detail['amount'];
      return amount == null ? '' : '${numberLabel(amount)}ml';
    case 'poop':
      final shape = detail['poopShape'];
      final color = detail['poopColor'];
      final kindLabel = shape == 'urine' ? '소변' : '대변';
      final colorLabel = poopColorLabel(color);
      return colorLabel.isEmpty ? kindLabel : '$kindLabel · $colorLabel';
    case 'walk':
      final distance = detail['distance'];
      return distance == null ? '' : '${numberLabel(distance)}km';
    case 'medicine':
      return '';
    case 'vet':
      return detail['vetVisitReason']?.toString().trim() ?? '';
    case 'weight':
      final value = weightValue(record);
      return value == null ? '' : '${numberLabel(value)}kg';
    case 'diary':
    case 'etc':
      return record.note?.trim() ?? '';
    default:
      final note = record.note?.trim();
      if (note != null && note.isNotEmpty) return note;
      return '${recordTypeLabel(record.typeId)} 기록';
  }
}

String recordTimeLabel(String? time) {
  final value = time?.trim();
  if (value == null || value.isEmpty) {
    return '--:--';
  }

  final parsedDateTime = DateTime.tryParse(value);
  if (parsedDateTime != null) {
    return DateFormat('HH:mm').format(parsedDateTime);
  }

  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) {
    return value;
  }
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
}

double? weightValue(ActivityRecord record) {
  final value = record.detail['weight'] ?? record.detail['value'];
  if (value == null) return null;
  return double.tryParse(value.toString());
}

String numberLabel(Object value) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  if (parsed == null) return value.toString();
  final rounded = parsed.toStringAsFixed(2);
  final withoutTrailingZeros = rounded
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return withoutTrailingZeros;
}

String mealFoodTypeLabel(Object? value) {
  return switch (value?.toString()) {
    'wet' => '습식',
    'dry' => '건식',
    'snack' => '간식',
    'prescription' => '처방식',
    'raw' => '생식',
    'freezeDried' => '동결건조',
    _ => '',
  };
}

String mealFeedingMethodLabel(Object? value) {
  return switch (value?.toString()) {
    'served' => '배식',
    'freeFeed' => '자율급식',
    'autoFeeder' => '자동급식기',
    _ => '',
  };
}

String poopShapeLabel(Object? value) {
  return switch (value?.toString()) {
    'urine' => '소변',
    'normal' => '보통 변',
    'loose' => '묽은 변',
    'diarrhea' => '설사',
    _ => '',
  };
}

String poopColorLabel(Object? value) {
  return switch (value?.toString()) {
    'brown' => '갈색',
    'lightBrown' => '연갈색',
    'red' => '붉은색',
    'black' => '검은색',
    'green' => '녹색',
    'other' => '기타',
    'clear' => '투명',
    'lightYellow' => '연노랑',
    'yellow' => '노랑',
    'darkYellow' => '진노랑',
    _ => '',
  };
}
