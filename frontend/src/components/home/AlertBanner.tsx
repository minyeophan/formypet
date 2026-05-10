import { View } from 'react-native';
import { usePets } from '@/src/lib/pet-context';
import { getActiveDates } from '@/src/services/records';
import { todayString } from '@/src/lib/utils';
import AppText from '../shared/AppText';

export default function AlertBanner() {
  const { pets, activePetId, records } = usePets();
  const pet = pets.find((p) => p.id === activePetId);

  if (!pet) return null;

  const activeDates = getActiveDates(records, pet.id);
  const hasActivityToday = activeDates.has(todayString());

  if (hasActivityToday) return null;

  return (
    <View
      style={{
        marginHorizontal: 20,
        marginBottom: 8,
        backgroundColor: '#FFF3E0',
        borderRadius: 14,
        paddingHorizontal: 16,
        paddingVertical: 12,
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
      }}
    >
      <AppText style={{ fontSize: 20 }}>🔔</AppText>
      <View style={{ flex: 1 }}>
        <AppText bold style={{ fontSize: 13, color: '#E65100' }}>
          오늘 기록이 없어요
        </AppText>
        <AppText style={{ fontSize: 12, color: '#BF360C', marginTop: 2 }}>
          {pet.name}의 하루를 기록해 주세요!
        </AppText>
      </View>
    </View>
  );
}
