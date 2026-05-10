import { useEffect, useRef, useState } from 'react';
import { NativeScrollEvent, NativeSyntheticEvent, ScrollView, View } from 'react-native';
import AppText from './AppText';

const ITEM_H = 44;
const VISIBLE = 3;

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

// HH:MM(24h) → { ampm, h12, minIndex }
function parseTo12h(value: string) {
  const match = value.match(/^(\d{2}):(\d{2})$/);
  const h24 = match ? parseInt(match[1], 10) : 9;
  const min = match ? parseInt(match[2], 10) : 0;
  const ampm = h24 < 12 ? 0 : 1; // 0=오전, 1=오후
  let h12 = h24 % 12;
  if (h12 === 0) h12 = 12;
  const minIndex = Math.round(min / 5);
  return { ampm, h12, minIndex };
}

const AMPM = ['오전', '오후'];
const HOURS = Array.from({ length: 12 }, (_, i) => String(i + 1));
const MINUTES = Array.from({ length: 12 }, (_, i) => String(i * 5).padStart(2, '0'));

export default function DrumRollTimePicker({
  value,
  onChange,
}: {
  value: string;
  onChange: (t: string) => void;
}) {
  const init = parseTo12h(value);
  const [ampm, setAmpm] = useState(init.ampm);
  const [h12, setH12] = useState(init.h12);
  const [minIndex, setMinIndex] = useState(init.minIndex);

  function emit(a: number, h: number, m: number) {
    let h24 = h % 12;
    if (a === 1) h24 += 12;
    onChange(`${String(h24).padStart(2, '0')}:${MINUTES[m]}`);
  }

  function handleAmpm(i: number) { setAmpm(i); emit(i, h12, minIndex); }
  function handleHour(i: number) { setH12(i + 1); emit(ampm, i + 1, minIndex); }
  function handleMin(i: number) { setMinIndex(i); emit(ampm, h12, i); }

  return (
    <View style={{ flexDirection: 'row', backgroundColor: '#F5F3EF', borderRadius: 16, paddingHorizontal: 8, overflow: 'hidden' }}>
      <Column items={AMPM} selectedIndex={ampm} onSelect={handleAmpm} />
      <View style={{ width: 1, backgroundColor: '#E8E4DE', marginVertical: 8 }} />
      <Column items={HOURS} selectedIndex={h12 - 1} onSelect={handleHour} />
      <View style={{ width: 1, backgroundColor: '#E8E4DE', marginVertical: 8 }} />
      <Column items={MINUTES} selectedIndex={minIndex} onSelect={handleMin} />
    </View>
  );
}

// 24h HH:MM → "오전 9:00" / "오후 2:30" 표시용
export function formatTime12h(hhmm: string): string {
  const { ampm, h12, minIndex } = parseTo12h(hhmm);
  return `${AMPM[ampm]} ${h12}:${MINUTES[minIndex]}`;
}
