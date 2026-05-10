import { router } from 'expo-router';
import { Pressable, ScrollView, View } from 'react-native';
import { usePets } from '@/src/lib/pet-context';
import { getSpeciesEmoji } from '@/src/lib/record-types';
import AppText from '../shared/AppText';

export default function PetSelector() {
  const { pets, activePetId, setActivePetId } = usePets();

  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={{ paddingHorizontal: 20, paddingTop: 10, paddingBottom: 14, gap: 12 }}
    >
      {pets.map((item) => {
        const isActive = item.id === activePetId;
        return (
          <Pressable
            key={item.id}
            onPress={() => setActivePetId(item.id)}
            style={{ alignItems: 'center', gap: 4 }}
          >
            <View
              style={{
                width: 52,
                height: 52,
                borderRadius: 26,
                backgroundColor: item.bgLight,
                borderWidth: isActive ? 2.5 : 0,
                borderColor: item.accentColor,
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <AppText style={{ fontSize: 24 }}>{getSpeciesEmoji(item.species)}</AppText>
            </View>
            <AppText
              bold={isActive}
              style={{ fontSize: 11, color: isActive ? item.accentColor : '#B0A99F' }}
            >
              {item.name}
            </AppText>
          </Pressable>
        );
      })}

      <Pressable
        onPress={() => router.push('/(tabs)/my')}
        style={{ alignItems: 'center', gap: 4 }}
      >
        <View
          style={{
            width: 52,
            height: 52,
            borderRadius: 26,
            backgroundColor: '#F0EDE8',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <AppText style={{ fontSize: 22, color: '#B0A99F' }}>+</AppText>
        </View>
        <AppText style={{ fontSize: 11, color: '#B0A99F' }}>추가</AppText>
      </Pressable>
    </ScrollView>
  );
}
