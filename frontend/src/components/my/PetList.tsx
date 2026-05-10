import { Pressable, View } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { usePets } from '@/src/lib/pet-context';
import { getSpeciesEmoji, SPECIES_LIST } from '@/src/lib/record-types';
import { getDDay } from '@/src/lib/utils';
import AppText from '../shared/AppText';

export default function PetList() {
  const { pets } = usePets();

  return (
    <View style={{ gap: 10 }}>
      {pets.map((item) => {
        const dDay = getDDay(item.birthDate);
        const years = Math.floor(dDay / 365);
        const months = Math.floor((dDay % 365) / 30);
        const ageText = years > 0 ? `${years}살 ${months}개월` : `${months}개월`;
        const speciesLabel = SPECIES_LIST.find((s) => s.id === item.species)?.label ?? item.species;

        return (
          <View
            key={item.id}
            style={{
              backgroundColor: item.bgLight,
              borderRadius: 16,
              padding: 16,
              flexDirection: 'row',
              alignItems: 'center',
              gap: 14,
              borderLeftWidth: 4,
              borderLeftColor: item.accentColor,
            }}
          >
            <View
              style={{
                width: 52, height: 52, borderRadius: 26,
                backgroundColor: 'rgba(255,255,255,0.7)',
                alignItems: 'center', justifyContent: 'center',
              }}
            >
              <AppText style={{ fontSize: 28 }}>{getSpeciesEmoji(item.species)}</AppText>
            </View>
            <View style={{ flex: 1 }}>
              <AppText bold style={{ fontSize: 16, color: '#1A1A1A' }}>{item.name}</AppText>
              <AppText style={{ fontSize: 12, color: '#6B6B6B', marginTop: 2 }}>
                {speciesLabel} · {ageText}
              </AppText>
              <AppText style={{ fontSize: 11, color: item.accentColor, marginTop: 4 }}>
                함께한 지 {dDay}일째
              </AppText>
            </View>
            <Pressable
              onPress={() => router.push(`/pet/${item.id}`)}
              style={{
                width: 36, height: 36, borderRadius: 18,
                backgroundColor: 'rgba(0,0,0,0.06)',
                alignItems: 'center', justifyContent: 'center',
              }}
            >
              <Ionicons name="create-outline" size={18} color="#6B6B6B" />
            </Pressable>
          </View>
        );
      })}
    </View>
  );
}
