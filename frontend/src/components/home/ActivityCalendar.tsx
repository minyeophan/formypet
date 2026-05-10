import { useState } from 'react';
import { Pressable, View } from 'react-native';
import { usePets } from '@/src/lib/pet-context';
import { getActiveDates } from '@/src/services/records';
import { getCalendarDays, todayString } from '@/src/lib/utils';
import AppText from '../shared/AppText';

const DAY_LABELS = ['일', '월', '화', '수', '목', '금', '토'];

export default function ActivityCalendar() {
  const { pets, activePetId, records } = usePets();
  const pet = pets.find((p) => p.id === activePetId);

  const today = new Date();
  const [year] = useState(today.getFullYear());
  const [month] = useState(today.getMonth()); // 0-indexed

  if (!pet) return null;

  const days = getCalendarDays(year, month); // 'YYYY-MM-DD' 배열
  const activeDates = getActiveDates(records, pet.id);
  const todayStr = todayString();

  // 첫 날의 요일 오프셋 (일=0)
  const firstDow = new Date(year, month, 1).getDay();
  const blanks = Array(firstDow).fill(null);

  const monthLabel = `${year}년 ${month + 1}월`;

  return (
    <View style={{ marginHorizontal: 20, marginBottom: 8 }}>
      <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginBottom: 12 }}>{monthLabel}</AppText>

      {/* 요일 헤더 */}
      <View style={{ flexDirection: 'row', marginBottom: 8 }}>
        {DAY_LABELS.map((d) => (
          <AppText
            key={d}
            bold
            style={{ flex: 1, textAlign: 'center', fontSize: 11, color: '#B0A99F' }}
          >
            {d}
          </AppText>
        ))}
      </View>

      {/* 날짜 그리드 */}
      <View style={{ flexDirection: 'row', flexWrap: 'wrap' }}>
        {blanks.map((_, i) => (
          <View key={`blank-${i}`} style={{ width: `${100 / 7}%`, aspectRatio: 1 }} />
        ))}
        {days.map((dateStr) => {
          const day = parseInt(dateStr.split('-')[2], 10);
          const isToday = dateStr === todayStr;
          const hasActivity = activeDates.has(dateStr);

          return (
            <View
              key={dateStr}
              style={{ width: `${100 / 7}%`, aspectRatio: 1, alignItems: 'center', justifyContent: 'center' }}
            >
              <View
                style={{
                  width: 32,
                  height: 32,
                  borderRadius: 16,
                  backgroundColor: isToday ? pet.accentColor : 'transparent',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <AppText
                  bold={isToday}
                  style={{ fontSize: 13, color: isToday ? '#FFFFFF' : '#1A1A1A' }}
                >
                  {day}
                </AppText>
              </View>
              {hasActivity && !isToday && (
                <View
                  style={{
                    width: 5,
                    height: 5,
                    borderRadius: 3,
                    backgroundColor: pet.accentColor,
                    marginTop: 2,
                  }}
                />
              )}
            </View>
          );
        })}
      </View>
    </View>
  );
}
