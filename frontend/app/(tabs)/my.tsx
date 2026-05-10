import { useState } from 'react';
import { ScrollView, View, Pressable } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import PetList from '@/src/components/my/PetList';
import PetRegisterForm from '@/src/components/onboarding/PetRegisterForm';
import { usePets } from '@/src/lib/pet-context';
import AppText from '@/src/components/shared/AppText';
import { colors } from '@/src/lib/colors';

export default function MyScreen() {
  const { pets } = usePets();
  const [showAddForm, setShowAddForm] = useState(false);

  if (showAddForm) {
    return (
      <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: '#F5F3EF' }}>
        <Pressable
          onPress={() => setShowAddForm(false)}
          style={{ paddingHorizontal: 20, paddingTop: 12, paddingBottom: 4 }}
        >
          <AppText style={{ fontSize: 14, color: colors.primary }}>← 돌아가기</AppText>
        </Pressable>
        <PetRegisterForm onComplete={() => setShowAddForm(false)} skipOnboarding />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: '#F5F3EF' }}>
      <View style={{ paddingHorizontal: 20, paddingTop: 8, paddingBottom: 12 }}>
        <AppText bold style={{ fontSize: 20, color: '#1A1A1A' }}>마이</AppText>
        <AppText style={{ fontSize: 13, color: '#B0A99F', marginTop: 2 }}>
          {pets.length}마리와 함께하고 있어요
        </AppText>
      </View>

      <ScrollView contentContainerStyle={{ padding: 20, paddingTop: 4 }}>
        <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginBottom: 12 }}>
          내 반려동물
        </AppText>

        <PetList />

        <Pressable
          onPress={() => setShowAddForm(true)}
          style={{
            marginTop: 12,
            borderWidth: 2,
            borderColor: colors.border,
            borderStyle: 'dashed',
            borderRadius: 16,
            padding: 20,
            alignItems: 'center',
            gap: 6,
          }}
        >
          <AppText style={{ fontSize: 28 }}>+</AppText>
          <AppText style={{ fontSize: 14, color: '#B0A99F' }}>반려동물 추가</AppText>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}
