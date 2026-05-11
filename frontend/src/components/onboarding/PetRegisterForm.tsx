import { useRef, useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { Pressable, ScrollView, TextInput, View } from 'react-native';
import AppText from '../shared/AppText';
import DrumRollDatePicker from '../shared/DrumRollDatePicker';
import { SPECIES_LIST } from '@/src/lib/record-types';
import { usePets } from '@/src/lib/pet-context';
import { todayString } from '@/src/lib/utils';

interface FormValues {
  name: string;
  species: string;
  birthDate: string;
  gender: 'male' | 'female' | '';
}

export default function PetRegisterForm({ onComplete, skipOnboarding }: { onComplete: () => void; skipOnboarding?: boolean }) {
  const { addPet, setHasOnboarded } = usePets();
  const [submitting, setSubmitting] = useState(false);
  const submittingRef = useRef(false);
  const { control, handleSubmit, setValue, watch, formState: { errors } } = useForm<FormValues>({
    defaultValues: { name: '', species: '', birthDate: todayString(), gender: '' },
  });

  const selectedSpecies = watch('species');
  const selectedGender = watch('gender');

  async function onSubmit(data: FormValues) {
    if (submittingRef.current || !data.name.trim() || !data.species) return;
    submittingRef.current = true;
    setSubmitting(true);
    try {
      await addPet({
        name: data.name.trim(),
        species: data.species,
        birthDate: data.birthDate,
        ...(data.gender ? { gender: data.gender } : {}),
      });
      if (!skipOnboarding) setHasOnboarded(true);
      onComplete();
    } finally {
      submittingRef.current = false;
      setSubmitting(false);
    }
  }

  return (
    <ScrollView style={{ flex: 1, backgroundColor: '#F5F3EF' }} keyboardDismissMode="on-drag" contentContainerStyle={{ padding: 24 }}>
      <AppText bold style={{ fontSize: 22, color: '#1A1A1A', marginBottom: 4 }}>반려동물 등록</AppText>
      <AppText style={{ fontSize: 14, color: '#6B6B6B', marginBottom: 28 }}>첫 번째 반려동물을 등록해 주세요.</AppText>

      {/* 종류 */}
      <AppText bold style={{ fontSize: 13, color: '#3A3A3A', marginBottom: 10 }}>종류</AppText>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 20 }}>
        {SPECIES_LIST.map((s) => (
          <Pressable
            key={s.id}
            onPress={() => setValue('species', s.id)}
            style={{
              paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20,
              backgroundColor: selectedSpecies === s.id ? '#F4A460' : '#FFFFFF',
              borderWidth: 1,
              borderColor: selectedSpecies === s.id ? '#F4A460' : '#E8E4DE',
            }}
          >
            <AppText style={{ fontSize: 13, color: selectedSpecies === s.id ? '#FFFFFF' : '#3A3A3A' }}>
              {s.emoji} {s.label}
            </AppText>
          </Pressable>
        ))}
      </View>

      {/* 이름 */}
      <AppText bold style={{ fontSize: 13, color: '#3A3A3A', marginBottom: 8 }}>이름</AppText>
      <Controller
        control={control}
        name="name"
        rules={{ required: '이름을 입력해 주세요', maxLength: { value: 6, message: '이름은 최대 6자까지 입력 가능해요' } }}
        render={({ field: { onChange, value } }) => (
          <TextInput
            value={value}
            onChangeText={onChange}
            placeholder="예: 초코"
            maxLength={6}
            returnKeyType="done"
            blurOnSubmit
            style={{
              backgroundColor: '#FFFFFF', borderWidth: 1, borderColor: '#E8E4DE',
              borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12,
              fontSize: 15, color: '#1A1A1A', marginBottom: 4,
            }}
            placeholderTextColor="#B0A99F"
          />
        )}
      />
      {errors.name && <AppText style={{ fontSize: 12, color: '#EF4444', marginBottom: 12 }}>{errors.name.message}</AppText>}

      {/* 성별 */}
      <AppText bold style={{ fontSize: 13, color: '#3A3A3A', marginBottom: 8, marginTop: 12 }}>성별 (선택)</AppText>
      <View style={{ flexDirection: 'row', gap: 10, marginBottom: 20 }}>
        {(['male', 'female'] as const).map((g) => (
          <Pressable
            key={g}
            onPress={() => setValue('gender', selectedGender === g ? '' : g)}
            style={{
              flex: 1, paddingVertical: 10, borderRadius: 12, alignItems: 'center',
              backgroundColor: selectedGender === g ? '#F4A460' : '#FFFFFF',
              borderWidth: 1,
              borderColor: selectedGender === g ? '#F4A460' : '#E8E4DE',
            }}
          >
            <AppText style={{ fontSize: 14, color: selectedGender === g ? '#FFFFFF' : '#6B6B6B' }}>
              {g === 'male' ? '♂ 수컷' : '♀ 암컷'}
            </AppText>
          </Pressable>
        ))}
      </View>

      {/* 생일 */}
      <AppText bold style={{ fontSize: 13, color: '#3A3A3A', marginBottom: 10, marginTop: 4 }}>생일</AppText>
      <Controller
        control={control}
        name="birthDate"
        render={({ field: { onChange, value } }) => (
          <DrumRollDatePicker value={value} onChange={onChange} />
        )}
      />

      {/* 등록 버튼 */}
      <Pressable
        onPress={handleSubmit(onSubmit)}
        disabled={submitting}
        style={{
          backgroundColor: '#F4A460', borderRadius: 16, paddingVertical: 16,
          alignItems: 'center', marginTop: 32, opacity: submitting ? 0.7 : 1,
        }}
      >
        <AppText bold style={{ color: '#FFFFFF', fontSize: 15 }}>{submitting ? '등록 중...' : '시작하기'}</AppText>
      </Pressable>
    </ScrollView>
  );
}
