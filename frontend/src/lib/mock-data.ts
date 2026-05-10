import { Pet, ActivityRecord, Post } from '../types';
import { PET_COLORS } from './colors';

export const MOCK_PETS: Pet[] = [
  {
    id: 'pet-1',
    name: '초코',
    species: 'dog',
    birthDate: '2022-03-15',
    accentColor: PET_COLORS[0].accent,
    bgLight: PET_COLORS[0].bgLight,
  },
  {
    id: 'pet-2',
    name: '나비',
    species: 'cat',
    birthDate: '2023-07-22',
    accentColor: PET_COLORS[1].accent,
    bgLight: PET_COLORS[1].bgLight,
  },
];

export const MOCK_RECORDS: ActivityRecord[] = [
  { id: 'r-1',  petId: 'pet-1', typeId: 'meal',     date: '2026-05-07', note: '사료 80g' },
  { id: 'r-2',  petId: 'pet-1', typeId: 'walk',     date: '2026-05-07', note: '30분 산책' },
  { id: 'r-3',  petId: 'pet-1', typeId: 'weight',   date: '2026-05-07', weight: 4.2 },
  { id: 'r-4',  petId: 'pet-1', typeId: 'meal',     date: '2026-05-06', note: '사료 80g' },
  { id: 'r-5',  petId: 'pet-1', typeId: 'play',     date: '2026-05-06', note: '공놀이 20분' },
  { id: 'r-6',  petId: 'pet-1', typeId: 'vet',      date: '2026-05-05', note: '정기검진' },
  { id: 'r-7',  petId: 'pet-1', typeId: 'weight',   date: '2026-05-04', weight: 4.1 },
  { id: 'r-8',  petId: 'pet-1', typeId: 'walk',     date: '2026-05-04', note: '45분 산책' },
  { id: 'r-9',  petId: 'pet-1', typeId: 'medicine', date: '2026-05-03', note: '심장사상충 예방약' },
  { id: 'r-10', petId: 'pet-1', typeId: 'meal',     date: '2026-05-03', note: '사료 80g' },
  { id: 'r-11', petId: 'pet-1', typeId: 'weight',   date: '2026-04-28', weight: 4.0 },
  { id: 'r-12', petId: 'pet-1', typeId: 'groom',    date: '2026-04-25', note: '목욕' },
  { id: 'r-13', petId: 'pet-1', typeId: 'weight',   date: '2026-04-20', weight: 3.9 },
  { id: 'r-14', petId: 'pet-2', typeId: 'meal',     date: '2026-05-07', note: '캔 1/2개' },
  { id: 'r-15', petId: 'pet-2', typeId: 'play',     date: '2026-05-07', note: '낚싯대 놀이' },
  { id: 'r-16', petId: 'pet-2', typeId: 'weight',   date: '2026-05-06', weight: 3.5 },
];

export const MOCK_POSTS: Post[] = [
  {
    id: 'post-1',
    author: '멍냥집사',
    petSpecies: 'dog',
    content: '오늘 초코가 처음으로 앉아를 성공했어요! 🎉 간식으로 훈련한 보람이 있네요.',
    likes: 12,
    likedByMe: false,
    createdAt: '2026-05-07T09:30:00',
  },
  {
    id: 'post-2',
    author: '고양이엄마',
    petSpecies: 'cat',
    content: '나비가 새 장난감을 너무 좋아해요 ㅠㅠ 구름 모양 낚싯대인데 30분을 놀았네요.',
    likes: 8,
    likedByMe: true,
    createdAt: '2026-05-06T18:00:00',
  },
  {
    id: 'post-3',
    author: '햄스터아빠',
    petSpecies: 'hamster',
    content: '쪽쪽이가 드디어 체중 100g 돌파! 건강하게 잘 크고 있어요 🐹',
    likes: 24,
    likedByMe: false,
    createdAt: '2026-05-06T12:00:00',
  },
  {
    id: 'post-4',
    author: '거북이집사',
    petSpecies: 'turtle',
    content: '아이가 처음으로 손에서 먹이를 받아먹었어요. 3개월 만에 드디어 친해진 것 같아서 감동 😭',
    likes: 31,
    likedByMe: false,
    createdAt: '2026-05-05T20:00:00',
  },
];
