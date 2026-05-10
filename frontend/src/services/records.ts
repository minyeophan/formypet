import { ActivityRecord } from '../types';

export interface WeightPoint {
  date: string;
  weight: number;
}

export function getWeightHistory(records: ActivityRecord[], petId: string): WeightPoint[] {
  return records
    .filter((r) => r.petId === petId && r.typeId === 'weight' && r.weight !== undefined)
    .sort((a, b) => a.date.localeCompare(b.date))
    .map((r) => ({ date: r.date, weight: r.weight! }));
}

export function getRecordsByPet(records: ActivityRecord[], petId: string): ActivityRecord[] {
  return records
    .filter((r) => r.petId === petId)
    .sort((a, b) => b.date.localeCompare(a.date));
}

export function getActiveDates(records: ActivityRecord[], petId: string): Set<string> {
  return new Set(records.filter((r) => r.petId === petId).map((r) => r.date));
}

export function getLastActivityDate(records: ActivityRecord[], petId: string): string | null {
  const sorted = getRecordsByPet(records, petId);
  return sorted.length > 0 ? sorted[0].date : null;
}

// 날짜별 그룹핑 (SectionList용)
export interface RecordSection {
  title: string; // ISO 날짜 문자열 (섹션 헤더에서 포맷)
  data: ActivityRecord[];
}

export function groupRecordsByDate(records: ActivityRecord[]): RecordSection[] {
  const map = new Map<string, ActivityRecord[]>();
  for (const r of records) {
    if (!map.has(r.date)) map.set(r.date, []);
    map.get(r.date)!.push(r);
  }
  return Array.from(map.entries())
    .sort(([a], [b]) => b.localeCompare(a))
    .map(([date, data]) => ({ title: date, data }));
}
