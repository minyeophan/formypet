import { View } from 'react-native';
import { usePets } from '@/src/lib/pet-context';
import { getRecordsByPet } from '@/src/services/records';
import { QUICK_TYPES } from '@/src/lib/record-types';
import { formatDateShort, todayString } from '@/src/lib/utils';
import { getRecordSummary } from '@/src/lib/record-utils';
import AppText from '../shared/AppText';

export default function RecentRecords() {
  const { pets, activePetId, records } = usePets();
  const pet = pets.find((p) => p.id === activePetId);

  if (!pet) return null;

  const recentRecords = getRecordsByPet(records, pet.id).filter((r) => r.date === todayString()).slice(0, 3);

  if (recentRecords.length === 0) {
    return (
      <View style={{ paddingHorizontal: 16, paddingBottom: 16 }}>
        <View style={{ backgroundColor: '#F5F3EF', borderRadius: 16, padding: 24, alignItems: 'center' }}>
          <AppText style={{ fontSize: 32, marginBottom: 8 }}>📋</AppText>
          <AppText style={{ fontSize: 14, color: '#B0A99F' }}>아직 기록이 없어요</AppText>
        </View>
      </View>
    );
  }

  return (
    <View style={{ paddingHorizontal: 16, paddingBottom: 16 }}>
      {recentRecords.map((item, index) => {
        const typeInfo = QUICK_TYPES.find((t) => t.id === item.typeId);
        return (
          <View key={item.id}>
            {index > 0 && (
              <View style={{ height: 1, backgroundColor: '#F0EDE8', marginHorizontal: 4, marginVertical: 4 }} />
            )}
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 6 }}>
              <View style={{
                width: 40, height: 40, borderRadius: 12,
                backgroundColor: typeInfo?.bg ?? '#F5F3EF',
                alignItems: 'center', justifyContent: 'center',
              }}>
                <AppText style={{ fontSize: 20 }}>{typeInfo?.emoji ?? '📝'}</AppText>
              </View>
              <View style={{ flex: 1 }}>
                <AppText bold style={{ fontSize: 14, color: '#1A1A1A' }}>
                  {typeInfo?.label ?? item.typeId}
                </AppText>
                {(() => {
                  const summary = getRecordSummary(item);
                  return summary ? (
                    <AppText style={{ fontSize: 12, color: '#6B6B6B', marginTop: 2 }} numberOfLines={1}>
                      {summary}
                    </AppText>
                  ) : null;
                })()}
              </View>
              <AppText style={{ fontSize: 11, color: '#B0A99F' }}>{formatDateShort(item.date)}</AppText>
            </View>
          </View>
        );
      })}
    </View>
  );
}
