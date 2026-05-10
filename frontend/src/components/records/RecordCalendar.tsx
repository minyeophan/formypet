import { useState } from 'react';
import { Pressable, View } from 'react-native';
import { getCalendarDays, todayString } from '@/src/lib/utils';
import AppText from '../shared/AppText';

interface Props {
  markedDates: Set<string>;
  selectedDate: string;
  onSelect: (date: string) => void;
  accentColor: string;
  onTodayPress?: () => void;
}

const WEEKDAYS = ['일', '월', '화', '수', '목', '금', '토'];

export default function RecordCalendar({ markedDates, selectedDate, onSelect, accentColor, onTodayPress }: Props) {
  const today = todayString();
  const [viewYear, setViewYear] = useState(() => parseInt(today.slice(0, 4), 10));
  const [viewMonth, setViewMonth] = useState(() => parseInt(today.slice(5, 7), 10) - 1);

  const todayYear = parseInt(today.slice(0, 4), 10);
  const todayMonth = parseInt(today.slice(5, 7), 10) - 1;
  const isViewingToday = viewYear === todayYear && viewMonth === todayMonth;

  const days = getCalendarDays(viewYear, viewMonth);
  const firstDay = new Date(viewYear, viewMonth, 1).getDay();
  const blanks = Array(firstDay).fill(null);
  const cells = [...blanks, ...days];
  const remainder = cells.length % 7;
  if (remainder !== 0) for (let i = 0; i < 7 - remainder; i++) cells.push(null);

  function prevMonth() {
    if (viewMonth === 0) { setViewMonth(11); setViewYear(viewYear - 1); }
    else setViewMonth(viewMonth - 1);
  }

  function nextMonth() {
    if (viewMonth === 11) { setViewMonth(0); setViewYear(viewYear + 1); }
    else setViewMonth(viewMonth + 1);
  }

  function goToToday() {
    setViewYear(todayYear);
    setViewMonth(todayMonth);
    onTodayPress?.();
  }

  return (
    <View style={{ backgroundColor: '#FFFFFF', borderRadius: 20, marginHorizontal: 20, padding: 16 }}>
      {/* 월 헤더 */}
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
        <Pressable onPress={prevMonth} style={{ padding: 8 }}>
          <AppText style={{ fontSize: 18, color: '#6B6B6B' }}>‹</AppText>
        </Pressable>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <AppText bold style={{ fontSize: 16, color: '#1A1A1A' }}>
            {viewYear}년 {viewMonth + 1}월
          </AppText>
          {!isViewingToday && (
            <Pressable
              onPress={goToToday}
              style={{
                paddingHorizontal: 10, paddingVertical: 3, borderRadius: 12,
                backgroundColor: accentColor + '22', borderWidth: 1, borderColor: accentColor + '55',
              }}
            >
              <AppText style={{ fontSize: 11, color: accentColor }}>오늘</AppText>
            </Pressable>
          )}
        </View>
        <Pressable onPress={nextMonth} style={{ padding: 8 }}>
          <AppText style={{ fontSize: 18, color: '#6B6B6B' }}>›</AppText>
        </Pressable>
      </View>

      {/* 요일 헤더 */}
      <View style={{ flexDirection: 'row', marginBottom: 4 }}>
        {WEEKDAYS.map((d, i) => (
          <View key={d} style={{ flex: 1, alignItems: 'center' }}>
            <AppText style={{ fontSize: 12, color: i === 0 ? '#EF4444' : i === 6 ? '#3B82F6' : '#B0A99F' }}>{d}</AppText>
          </View>
        ))}
      </View>

      {/* 날짜 그리드 */}
      {Array.from({ length: cells.length / 7 }).map((_, rowIdx) => (
        <View key={rowIdx} style={{ flexDirection: 'row' }}>
          {cells.slice(rowIdx * 7, rowIdx * 7 + 7).map((date, colIdx) => {
            if (!date) return <View key={colIdx} style={{ flex: 1, height: 40 }} />;
            const isSelected = date === selectedDate;
            const isToday = date === today;
            const hasRecord = markedDates.has(date);
            const isSun = colIdx === 0;
            const isSat = colIdx === 6;
            return (
              <Pressable
                key={date}
                onPress={() => onSelect(date)}
                style={{ flex: 1, height: 40, alignItems: 'center', justifyContent: 'center' }}
              >
                <View style={{
                  width: 32, height: 32, borderRadius: 16,
                  alignItems: 'center', justifyContent: 'center',
                  backgroundColor: isSelected ? accentColor : 'transparent',
                  borderWidth: isToday && !isSelected ? 1.5 : 0,
                  borderColor: accentColor,
                }}>
                  <AppText bold={isSelected} style={{
                    fontSize: 14,
                    color: isSelected ? '#FFFFFF' : isSun ? '#EF4444' : isSat ? '#3B82F6' : '#1A1A1A',
                  }}>
                    {parseInt(date.slice(8), 10)}
                  </AppText>
                </View>
                {hasRecord && !isSelected && (
                  <View style={{ width: 4, height: 4, borderRadius: 2, backgroundColor: accentColor, marginTop: 1 }} />
                )}
                {!hasRecord && <View style={{ width: 4, height: 4, marginTop: 1 }} />}
              </Pressable>
            );
          })}
        </View>
      ))}
    </View>
  );
}
