import { getDaysInMonth } from 'date-fns';
import { useEffect, useRef, useState } from 'react';
import { NativeScrollEvent, NativeSyntheticEvent, ScrollView, View } from 'react-native';
import AppText from './AppText';

const ITEM_H = 44;
const VISIBLE = 3;

interface Props {
  value: string; // YYYY-MM-DD
  onChange: (date: string) => void;
}

function Column({
  items,
  selectedIndex,
  onSelect,
}: {
  items: string[];
  selectedIndex: number;
  onSelect: (index: number) => void;
}) {
  const ref = useRef<ScrollView>(null);

  useEffect(() => {
    setTimeout(() => {
      ref.current?.scrollTo({ y: selectedIndex * ITEM_H, animated: false });
    }, 50);
  }, []);

  function onScrollEnd(e: NativeSyntheticEvent<NativeScrollEvent>) {
    const index = Math.round(e.nativeEvent.contentOffset.y / ITEM_H);
    onSelect(Math.max(0, Math.min(index, items.length - 1)));
  }

  return (
    <View style={{ flex: 1, height: ITEM_H * VISIBLE, overflow: 'hidden' }}>
      {/* 선택 행 하이라이트 */}
      <View
        pointerEvents="none"
        style={{
          position: 'absolute',
          top: ITEM_H,
          left: 0,
          right: 0,
          height: ITEM_H,
          backgroundColor: 'rgba(0,0,0,0.06)',
          borderRadius: 10,
          zIndex: 1,
        }}
      />
      <ScrollView
        ref={ref}
        onStartShouldSetResponder={() => true}
        onMoveShouldSetResponder={() => true}
        showsVerticalScrollIndicator={false}
        snapToInterval={ITEM_H}
        decelerationRate="fast"
        onMomentumScrollEnd={onScrollEnd}
        contentContainerStyle={{ paddingVertical: ITEM_H }}
        nestedScrollEnabled
      >
        {items.map((item, i) => (
          <View key={item} style={{ height: ITEM_H, alignItems: 'center', justifyContent: 'center' }}>
            <AppText
              bold={i === selectedIndex}
              style={{ fontSize: 17, color: i === selectedIndex ? '#1A1A1A' : '#B0A99F' }}
            >
              {item}
            </AppText>
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

export default function DrumRollDatePicker({ value, onChange }: Props) {
  const currentYear = new Date().getFullYear();
  const years = Array.from({ length: currentYear - 1979 }, (_, i) => String(1980 + i));
  const months = Array.from({ length: 12 }, (_, i) => String(i + 1).padStart(2, '0'));

  const parsed = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  const initYear = parsed ? parsed[1] : String(currentYear);
  const initMonth = parsed ? parsed[2] : '01';
  const initDay = parsed ? parsed[3] : '01';

  const [selYear, setSelYear] = useState(initYear);
  const [selMonth, setSelMonth] = useState(initMonth);
  const [selDay, setSelDay] = useState(initDay);

  function getDays(y: string, m: string) {
    const count = getDaysInMonth(new Date(Number(y), Number(m) - 1));
    return Array.from({ length: count }, (_, i) => String(i + 1).padStart(2, '0'));
  }

  const days = getDays(selYear, selMonth);

  function clampDay(y: string, m: string, d: string) {
    const max = getDaysInMonth(new Date(Number(y), Number(m) - 1));
    const num = Math.min(Number(d), max);
    return String(num).padStart(2, '0');
  }

  function handleYear(i: number) {
    const y = years[i];
    const d = clampDay(y, selMonth, selDay);
    setSelYear(y);
    setSelDay(d);
    onChange(`${y}-${selMonth}-${d}`);
  }

  function handleMonth(i: number) {
    const m = months[i];
    const d = clampDay(selYear, m, selDay);
    setSelMonth(m);
    setSelDay(d);
    onChange(`${selYear}-${m}-${d}`);
  }

  function handleDay(i: number) {
    const d = days[i];
    setSelDay(d);
    onChange(`${selYear}-${selMonth}-${d}`);
  }

  return (
    <View
      style={{
        flexDirection: 'row',
        backgroundColor: '#F5F3EF',
        borderRadius: 16,
        paddingHorizontal: 8,
        overflow: 'hidden',
      }}
    >
      <Column items={years} selectedIndex={years.indexOf(selYear)} onSelect={handleYear} />
      <View style={{ width: 1, backgroundColor: '#E8E4DE', marginVertical: 8 }} />
      <Column items={months} selectedIndex={months.indexOf(selMonth)} onSelect={handleMonth} />
      <View style={{ width: 1, backgroundColor: '#E8E4DE', marginVertical: 8 }} />
      <Column items={days} selectedIndex={days.indexOf(selDay)} onSelect={handleDay} />
    </View>
  );
}
