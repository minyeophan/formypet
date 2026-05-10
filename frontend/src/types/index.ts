export interface Pet {
  id: string;
  name: string;
  species: string;
  birthDate: string; // ISO 날짜 문자열 YYYY-MM-DD
  accentColor: string;
  bgLight: string;
  gender?: 'male' | 'female';
  weight?: number;
  animalRegistrationNumber?: string;
  neutered?: boolean;
  specialNotes?: string;
  diseases?: string;
}

export interface ActivityRecord {
  id: string;
  petId: string;
  typeId: string;
  date: string; // ISO 날짜 문자열 YYYY-MM-DD
  time?: string; // HH:MM
  note?: string;
  weight?: number; // kg

  // 식사
  foodType?: 'wet' | 'dry' | 'treat' | 'prescription' | 'raw' | 'freezeDried' | 'other';
  feedingMethod?: 'hand' | 'free' | 'autoFeeder' | 'other';
  servedAmount?: number; // 급여량 (g)
  consumedAmount?: number; // 직접 섭취량 (g)
  consumedPercent?: number; // 섭취율 (%)
  brand?: string; // 브랜드명
  product?: string; // 제품명
  ingredients?: string; // 성분/기타 메모

  // 음수
  amount?: number; // 음수(ml)

  // 투약
  medicineName?: string;
  dosage?: string;

  // 배변
  poopShape?: 'normal' | 'soft' | 'hard' | 'liquid' | 'thin' | 'pellet';
  poopColor?: 'yellow' | 'lightBrown' | 'brown' | 'darkBrown' | 'black' | 'red' | 'green' | 'other';
  poopAmount?: 'small' | 'normal' | 'large';
  poopSmell?: 'none' | 'mild' | 'strong' | 'veryStrong';
  poopPhotos?: string[]; // 로컬 이미지 URI (최대 3개)

  // 산책
  distance?: number; // 거리(m)
  duration?: number; // 산책·수면·놀이: 시간(분)

  // 병원
  vetClinicName?: string;
  vetVisitReason?: 'checkup' | 'vaccination' | 'treatment' | 'surgery' | 'other';
  vetDiagnosis?: string;
  vetTreatment?: string;
  vetCost?: number;
  vetNextVisitDate?: string; // YYYY-MM-DD

  routineId?: string;
}

export interface Routine {
  id: string;
  petId: string;
  label: string;
  typeId: string;
  repeatType: 'daily' | 'weekly' | 'biweekly' | 'monthly';
  days: number[]; // 0=일~6=토 (weekly/biweekly만)
  monthlyInterval?: number; // monthly만 (1=매달, 3=분기별), default 1
  startDate: string; // YYYY-MM-DD
  times: string[]; // HH:MM 배열
  note?: string;
  detail?: Partial<ActivityRecord>;
  notificationEnabled: boolean;
  notificationIds: string[];
}

export interface Post {
  id: string;
  author: string;
  petSpecies: string;
  content: string;
  likes: number;
  likedByMe: boolean;
  createdAt: string; // ISO 날짜 문자열
}
