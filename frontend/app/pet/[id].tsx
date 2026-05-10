import { Alert, Pressable, ScrollView, View } from 'react-native';
import { useLocalSearchParams, router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import Toast from 'react-native-toast-message';
import { usePets } from '@/src/lib/pet-context';
import { getSpeciesEmoji, SPECIES_LIST } from '@/src/lib/record-types';
import { getDDay } from '@/src/lib/utils';
import { getWeightHistory } from '@/src/services/records';
import AppText from '@/src/components/shared/AppText';
import { colors } from '@/src/lib/colors';

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: '#F0EDE8' }}>
      <AppText style={{ fontSize: 14, color: '#6B6B6B', width: 120 }}>{label}</AppText>
      <AppText bold style={{ fontSize: 14, color: '#1A1A1A', flex: 1 }}>{value}</AppText>
    </View>
  );
}

export default function PetDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const insets = useSafeAreaInsets();
  const { pets, records, deletePet } = usePets();
  const pet = pets.find((p) => p.id === id);

  if (!pet) return null;

  const dDay = getDDay(pet.birthDate);
  const years = Math.floor(dDay / 365);
  const months = Math.floor((dDay % 365) / 30);
  const ageText = years > 0 ? `${years}살 ${months}개월` : `${months}개월`;
  const speciesLabel = SPECIES_LIST.find((s) => s.id === pet.species)?.label ?? pet.species;
  const weightHistory = getWeightHistory(records, pet.id);
  const latestWeight = weightHistory.length > 0 ? weightHistory[weightHistory.length - 1].weight : (pet.weight ?? null);
  const genderLabel = pet.gender === 'male' ? '수컷 ♂' : pet.gender === 'female' ? '암컷 ♀' : '미입력';

  function confirmDelete() {
    Alert.alert(
      `${pet!.name} 삭제`,
      '삭제하면 해당 반려동물의 모든 기록도 함께 삭제됩니다. 정말 삭제할까요?',
      [
        { text: '취소', style: 'cancel' },
        {
          text: '삭제', style: 'destructive',
          onPress: async () => {
            try {
              await deletePet(pet!.id);
              router.back();
            } catch (error) {
              Toast.show({ type: 'error', text1: error instanceof Error ? error.message : 'Delete failed' });
            }
          },
        },
      ]
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: '#F5F3EF', paddingTop: insets.top }}>
      {/* 헤더 */}
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 12 }}>
        <Pressable onPress={() => router.back()} style={{ marginRight: 8 }}>
          <Ionicons name="chevron-back" size={26} color="#1A1A1A" />
        </Pressable>
        <AppText bold style={{ fontSize: 17, color: '#1A1A1A', flex: 1 }}>내 반려동물</AppText>
        <Pressable onPress={() => router.push(`/pet/${id}/edit`)}>
          <Ionicons name="create-outline" size={22} color="#6B6B6B" />
        </Pressable>
      </View>

      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: 32 }}>
        {/* 펫 프로필 카드 */}
        <View style={{ marginHorizontal: 20, backgroundColor: pet.bgLight, borderRadius: 20, padding: 20, flexDirection: 'row', alignItems: 'center', gap: 16, borderLeftWidth: 4, borderLeftColor: pet.accentColor }}>
          <View style={{ width: 64, height: 64, borderRadius: 32, backgroundColor: 'rgba(255,255,255,0.7)', alignItems: 'center', justifyContent: 'center' }}>
            <AppText style={{ fontSize: 34 }}>{getSpeciesEmoji(pet.species)}</AppText>
          </View>
          <View>
            <AppText bold style={{ fontSize: 20, color: '#1A1A1A' }}>{pet.name}</AppText>
            <AppText style={{ fontSize: 13, color: '#6B6B6B', marginTop: 2 }}>
              {speciesLabel}{pet.gender === 'male' ? ' · ♂' : pet.gender === 'female' ? ' · ♀' : ''} · {ageText}
            </AppText>
            <AppText style={{ fontSize: 12, color: pet.accentColor, marginTop: 4 }}>함께한 지 {dDay}일째</AppText>
          </View>
        </View>

        {/* 기본 정보 */}
        <View style={{ marginHorizontal: 20, marginTop: 16, backgroundColor: '#FFFFFF', borderRadius: 16, paddingHorizontal: 16 }}>
          <AppText bold style={{ fontSize: 12, color: '#B0A99F', marginTop: 14, marginBottom: 2 }}>기본 정보</AppText>
          <InfoRow label="나이" value={ageText} />
          <InfoRow label="함께한 날" value={`${dDay}일째`} />
          <InfoRow label="체중" value={latestWeight ? `${latestWeight}kg` : '미입력'} />
          <InfoRow label="성별" value={genderLabel} />
        </View>

        {/* 추가 정보 */}
        <View style={{ marginHorizontal: 20, marginTop: 12, backgroundColor: '#FFFFFF', borderRadius: 16, paddingHorizontal: 16 }}>
          <AppText bold style={{ fontSize: 12, color: '#B0A99F', marginTop: 14, marginBottom: 2 }}>추가 정보</AppText>
          <InfoRow label="중성화 여부" value={pet.neutered === true ? '완료' : pet.neutered === false ? '미완료' : '미입력'} />
          <InfoRow label="동물 등록번호" value={pet.animalRegistrationNumber || '미입력'} />
          <InfoRow label="특이사항" value={pet.specialNotes || '미입력'} />
          <InfoRow label="질병" value={pet.diseases || '미입력'} />
        </View>

        {/* 하단 버튼 */}
        <View style={{ flexDirection: 'row', gap: 10, marginHorizontal: 20, marginTop: 24 }}>
          <Pressable
            onPress={() => router.push(`/pet/${id}/edit`)}
            style={{ flex: 1, backgroundColor: colors.primary, borderRadius: 14, paddingVertical: 14, alignItems: 'center' }}
          >
            <AppText bold style={{ color: '#FFFFFF', fontSize: 14 }}>정보 수정</AppText>
          </Pressable>
          <Pressable
            onPress={confirmDelete}
            style={{ paddingHorizontal: 20, borderRadius: 14, paddingVertical: 14, alignItems: 'center', backgroundColor: '#F5F3EF', borderWidth: 1, borderColor: '#E8E4DE' }}
          >
            <AppText style={{ color: '#EF4444', fontSize: 14 }}>삭제</AppText>
          </Pressable>
        </View>
      </ScrollView>
    </View>
  );
}
