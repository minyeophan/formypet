export interface QuickType {
  id: string;
  label: string;
  emoji: string;
  bg: string;
  category: 'activity' | 'health' | 'growth';
}

export const QUICK_TYPES: QuickType[] = [
  { id: 'meal', label: '식사', emoji: '🍽️', bg: '#FFF3E0', category: 'activity' },
  { id: 'walk', label: '산책', emoji: '🐕', bg: '#E8F5E9', category: 'activity' },
  { id: 'poop', label: '배변', emoji: '💩', bg: '#FFF8F0', category: 'activity' },
  { id: 'water', label: '음수', emoji: '💧', bg: '#E0F4FF', category: 'activity' },
  { id: 'play', label: '놀이', emoji: '🎾', bg: '#E3F2FD', category: 'activity' },
  { id: 'sleep', label: '수면', emoji: '😴', bg: '#EDE7F6', category: 'activity' },
  { id: 'diary', label: '일기', emoji: '📝', bg: '#F5F5F5', category: 'activity' },
  { id: 'groom', label: '그루밍', emoji: '🧼', bg: '#FCE4EC', category: 'health' },
  { id: 'medicine', label: '투약', emoji: '💊', bg: '#FFF9C4', category: 'health' },
  { id: 'vet', label: '병원', emoji: '🏥', bg: '#FFEBEE', category: 'health' },
  { id: 'checkup', label: '검진', emoji: '🩺', bg: '#E8F5E9', category: 'health' },
  { id: 'weight', label: '체중', emoji: '⚖️', bg: '#F3E5F5', category: 'growth' },
];

export const DEFAULT_QUICK_IDS = ['meal', 'walk', 'poop', 'water'];

export const SPECIES_LIST = [
  { id: 'dog', label: '강아지', emoji: '🐶' },
  { id: 'cat', label: '고양이', emoji: '🐱' },
  { id: 'bird', label: '새/앵무새', emoji: '🐦' },
  { id: 'hamster', label: '햄스터', emoji: '🐹' },
  { id: 'rabbit', label: '토끼', emoji: '🐰' },
  { id: 'turtle', label: '거북이', emoji: '🐢' },
  { id: 'fish', label: '물고기', emoji: '🐟' },
  { id: 'other', label: '기타', emoji: '🐾' },
];

export function getSpeciesEmoji(speciesId: string): string {
  return SPECIES_LIST.find((s) => s.id === speciesId)?.emoji ?? '🐾';
}
