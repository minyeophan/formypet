import { ActivityRecord } from '../types';

const FOOD_TYPE_LABEL: Record<string, string> = {
  dry: '건식',
  wet: '습식',
  treat: '간식',
  prescription: '처방식',
  raw: '생식',
  freezeDried: '동결건조',
  other: '기타',
};

const POOP_SHAPE_LABEL: Record<string, string> = {
  normal: '정상',
  soft: '무름',
  hard: '딱딱함',
  liquid: '액체',
  thin: '가늘다',
  pellet: '알갱이',
};

const POOP_COLOR_LABEL: Record<string, string> = {
  yellow: '노랑',
  lightBrown: '연한 갈색',
  brown: '갈색',
  darkBrown: '진한 갈색',
  black: '검정',
  red: '빨강',
  green: '초록',
  other: '기타',
};

const VET_VISIT_REASON_LABEL: Record<string, string> = {
  checkup: '정기검진',
  vaccination: '예방접종',
  treatment: '치료',
  surgery: '수술',
  other: '기타',
};

const POOP_AMOUNT_LABEL: Record<string, string> = {
  small: '소량',
  normal: '보통',
  large: '대량',
};

export function getRecordSummary(record: ActivityRecord): string {
  switch (record.typeId) {
    case 'meal': {
      const parts = [
        record.foodType ? FOOD_TYPE_LABEL[record.foodType] : null,
        record.servedAmount != null ? `${record.servedAmount}g` : null,
      ].filter(Boolean);
      return parts.join(' · ') || record.note || '';
    }
    case 'water':
      return record.amount != null ? `${record.amount}ml` : record.note || '';
    case 'medicine': {
      const parts = [record.medicineName, record.dosage].filter(Boolean);
      return parts.join(' · ') || record.ingredients || record.note || '';
    }
    case 'poop': {
      const parts = [
        record.poopShape ? POOP_SHAPE_LABEL[record.poopShape] : null,
        record.poopColor ? POOP_COLOR_LABEL[record.poopColor] : null,
        record.poopAmount ? POOP_AMOUNT_LABEL[record.poopAmount] : null,
      ].filter(Boolean);
      return parts.join(' · ') || record.note || '';
    }
    case 'walk': {
      const parts = [
        record.distance != null ? `${record.distance}m` : null,
        record.duration != null ? `${record.duration}분` : null,
      ].filter(Boolean);
      return parts.join(' · ') || record.note || '';
    }
    case 'weight':
      return record.weight != null ? `${record.weight}kg` : record.note || '';
    case 'vet': {
      const parts = [
        record.vetClinicName,
        record.vetVisitReason ? VET_VISIT_REASON_LABEL[record.vetVisitReason] : null,
        record.vetDiagnosis,
      ].filter(Boolean);
      return parts.join(' · ') || record.note || '';
    }
    default:
      return record.note || '';
  }
}

export function formatTime(time: string): string {
  const [hStr, mStr] = time.split(':');
  const h = parseInt(hStr, 10);
  const m = mStr ?? '00';
  if (h < 12) return `오전 ${h === 0 ? 12 : h}:${m}`;
  return `오후 ${h === 12 ? 12 : h - 12}:${m}`;
}

export function sortByTime(records: ActivityRecord[]): ActivityRecord[] {
  return [...records].sort((a, b) => {
    if (a.time && b.time) return a.time.localeCompare(b.time);
    if (a.time) return -1;
    if (b.time) return 1;
    return 0;
  });
}
