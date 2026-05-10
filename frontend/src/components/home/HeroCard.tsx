import { LinearGradient } from 'expo-linear-gradient';
import { Pressable, View } from 'react-native';
import { router } from 'expo-router';
import { usePets } from '@/src/lib/pet-context';
import { getLastActivityDate, getWeightHistory } from '@/src/services/records';
import { getDDay, formatDateShort } from '@/src/lib/utils';
import { getSpeciesEmoji, SPECIES_LIST } from '@/src/lib/record-types';
import { colors } from '@/src/lib/colors';
import AppText from '../shared/AppText';

export default function HeroCard() {
  const { pets, activePetId, records } = usePets();
  const pet = pets.find((p) => p.id === activePetId);

  if (!pet) return null;

  const dDay = getDDay(pet.birthDate);
  const years = Math.floor(dDay / 365);
  const months = Math.floor((dDay % 365) / 30);
  const ageText = years > 0 ? `${years}살 ${months}개월` : `${months}개월`;
  const lastDate = getLastActivityDate(records, pet.id);
  const speciesLabel = SPECIES_LIST.find((s) => s.id === pet.species)?.label ?? pet.species;
  const weightHistory = getWeightHistory(records, pet.id);
  const latestWeight = weightHistory.length > 0 ? weightHistory[weightHistory.length - 1].weight : (pet.weight ?? null);
  const genderText = pet.gender === 'male' ? ' · ♂' : pet.gender === 'female' ? ' · ♀' : '';

  return (
    <View style={{ marginHorizontal: 20, marginBottom: 4 }}>
    <LinearGradient
      colors={[colors.surfaceSoft, pet.bgLight, pet.accentColor + '44']}
      start={{ x: 0, y: 0 }}
      end={{ x: 1, y: 1 }}
      style={{ borderRadius: 24, padding: 24, borderWidth: 1, borderColor: colors.border }}
    >
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <View style={{ flex: 1 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 }}>
            <AppText style={{ fontSize: 28 }}>{getSpeciesEmoji(pet.species)}</AppText>
            <AppText bold style={{ fontSize: 22, color: colors.text }}>{pet.name}</AppText>
          </View>

          <AppText style={{ fontSize: 13, color: colors.textSecondary, marginBottom: 4 }}>
            {speciesLabel}{genderText} · {ageText}
          </AppText>
          <AppText style={{ fontSize: 12, color: pet.accentColor, marginBottom: 12 }}>
            함께한 지 {dDay}일째{latestWeight ? ` · 체중 ${latestWeight}kg` : ''}
          </AppText>

          <View
            style={{
              backgroundColor: colors.surface,
              borderRadius: 12,
              borderWidth: 1,
              borderColor: colors.border,
              paddingHorizontal: 12,
              paddingVertical: 8,
              alignSelf: 'flex-start',
            }}
          >
            <AppText style={{ fontSize: 12, color: colors.textSecondary }}>마지막 기록</AppText>
            <AppText bold style={{ fontSize: 14, color: colors.text, marginTop: 2 }}>
              {lastDate ? formatDateShort(lastDate) : '아직 없어요'}
            </AppText>
          </View>
        </View>

        <View style={{ alignItems: 'flex-end', gap: 8 }}>
          <View
            style={{
              width: 72,
              height: 72,
              borderRadius: 36,
              backgroundColor: 'rgba(255,252,247,0.72)',
              borderWidth: 1,
              borderColor: colors.border,
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <AppText style={{ fontSize: 40 }}>{getSpeciesEmoji(pet.species)}</AppText>
          </View>
          <Pressable
            onPress={() => router.push('/growth')}
            style={{
              paddingHorizontal: 12, paddingVertical: 5, borderRadius: 20,
              backgroundColor: 'rgba(255,252,247,0.35)',
              borderWidth: 1,
              borderColor: 'rgba(255,252,247,0.5)',
            }}
          >
            <AppText style={{ fontSize: 12, color: '#FFFFFF' }}>📈 성장 곡선</AppText>
          </Pressable>
        </View>
      </View>
    </LinearGradient>
    </View>
  );
}
