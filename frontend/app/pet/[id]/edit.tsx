import { Controller, useForm } from 'react-hook-form';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, TextInput, View } from 'react-native';
import { useLocalSearchParams, router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import Toast from 'react-native-toast-message';
import { usePets } from '@/src/lib/pet-context';
import { getSpeciesEmoji, SPECIES_LIST } from '@/src/lib/record-types';
import AppText from '@/src/components/shared/AppText';
import DrumRollDatePicker from '@/src/components/shared/DrumRollDatePicker';
import NumericInputModal from '@/src/components/shared/NumericInputModal';
import MemoInput from '@/src/components/shared/MemoInput';
import { colors } from '@/src/lib/colors';

interface FormValues {
  name: string;
  species: string;
  birthDate: string;
  gender: 'male' | 'female' | '';
  weight: string;
  animalRegistrationNumber: string;
  neutered: boolean | null;
  diseases: string;
  specialNotes: string;
}

function SectionCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View style={{ backgroundColor: '#FFFFFF', borderRadius: 16, padding: 16, marginBottom: 12 }}>
      <AppText bold style={{ fontSize: 13, color: '#B0A99F', marginBottom: 14 }}>{title}</AppText>
      {children}
    </View>
  );
}

function FieldRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <View style={{ marginBottom: 16 }}>
      <AppText bold style={{ fontSize: 13, color: '#3A3A3A', marginBottom: 8 }}>{label}</AppText>
      {children}
    </View>
  );
}

function FieldInput({ value, onChange, placeholder, multiline, maxLength }: {
  value: string; onChange: (v: string) => void; placeholder?: string;
  multiline?: boolean; maxLength?: number;
}) {
  return (
    <TextInput
      value={value}
      onChangeText={onChange}
      placeholder={placeholder}
      placeholderTextColor="#B0A99F"
      multiline={multiline}
      maxLength={maxLength}
      returnKeyType={multiline ? undefined : 'done'}
      blurOnSubmit={!multiline}
      style={{
        backgroundColor: '#F5F3EF', borderWidth: 1, borderColor: '#E8E4DE',
        borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12,
        fontSize: 15, color: '#1A1A1A',
        minHeight: multiline ? 72 : undefined,
        textAlignVertical: multiline ? 'top' : undefined,
      }}
    />
  );
}

export default function PetEditScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const insets = useSafeAreaInsets();
  const { pets, updatePet } = usePets();
  const pet = pets.find((p) => p.id === id);

  const { control, handleSubmit, setValue, watch, formState: { errors } } = useForm<FormValues>({
    defaultValues: {
      name: pet?.name ?? '',
      species: pet?.species ?? '',
      birthDate: pet?.birthDate ?? '2020-01-01',
      gender: pet?.gender ?? '',
      weight: pet?.weight ? String(pet.weight) : '',
      animalRegistrationNumber: pet?.animalRegistrationNumber ?? '',
      neutered: pet?.neutered ?? null,
      diseases: pet?.diseases ?? '',
      specialNotes: pet?.specialNotes ?? '',
    },
  });

  const selectedSpecies = watch('species');
  const selectedGender = watch('gender');

  const [numpadConfig, setNumpadConfig] = useState<{
    label: string; unit?: string; value: string;
    onConfirm: (v: string) => void; allowDecimal?: boolean;
  } | null>(null);

  function openNum(label: string, value: string, unit: string | undefined, onConfirm: (v: string) => void, allowDecimal = true) {
    setNumpadConfig({ label, unit, value, onConfirm, allowDecimal });
  }

  const numFieldStyle = {
    backgroundColor: '#F5F3EF', borderWidth: 1, borderColor: '#E8E4DE',
    borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12,
    minHeight: 44, justifyContent: 'center' as const,
  };

  if (!pet) return null;

  async function onSubmit(data: FormValues) {
    try {
      await updatePet(id, {
        name: data.name.trim(),
        species: data.species,
        birthDate: data.birthDate,
        ...(data.gender ? { gender: data.gender } : { gender: undefined }),
        weight: data.weight ? Number(data.weight) : undefined,
        animalRegistrationNumber: data.animalRegistrationNumber || undefined,
        neutered: data.neutered ?? undefined,
        diseases: data.diseases || undefined,
        specialNotes: data.specialNotes || undefined,
      });
      Toast.show({ type: 'success', text1: '정보가 수정되었어요' });
      router.back();
    } catch (error) {
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : 'Update failed' });
    }
  }

  return (
    <KeyboardAvoidingView
      style={{ flex: 1, backgroundColor: '#F5F3EF' }}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={{ paddingTop: insets.top }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 12 }}>
          <Pressable onPress={() => router.back()} style={{ marginRight: 8 }}>
            <Ionicons name="chevron-back" size={26} color="#1A1A1A" />
          </Pressable>
          <AppText bold style={{ fontSize: 17, color: '#1A1A1A' }}>펫 정보 수정</AppText>
        </View>
      </View>

      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 16, paddingBottom: 40 }} keyboardShouldPersistTaps="handled" keyboardDismissMode="on-drag">
        {/* 이모지 미리보기 */}
        <View style={{ alignItems: 'center', marginBottom: 16 }}>
          <View style={{ width: 80, height: 80, borderRadius: 40, backgroundColor: pet.bgLight, alignItems: 'center', justifyContent: 'center', borderWidth: 2, borderColor: pet.accentColor }}>
            <AppText style={{ fontSize: 40 }}>{getSpeciesEmoji(selectedSpecies || pet.species)}</AppText>
          </View>
          <AppText style={{ fontSize: 12, color: '#B0A99F', marginTop: 6 }}>종 변경 시 이모지가 바뀝니다</AppText>
        </View>

        {/* 기본 정보 */}
        <SectionCard title="기본 정보">
          {/* 종류 */}
          <FieldRow label="종류">
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
              {SPECIES_LIST.map((s) => (
                <Pressable
                  key={s.id}
                  onPress={() => setValue('species', s.id)}
                  style={{
                    paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20,
                    backgroundColor: selectedSpecies === s.id ? colors.primary : '#F5F3EF',
                    borderWidth: 1,
                    borderColor: selectedSpecies === s.id ? colors.primary : '#E8E4DE',
                  }}
                >
                  <AppText style={{ fontSize: 13, color: selectedSpecies === s.id ? '#FFFFFF' : '#3A3A3A' }}>
                    {s.emoji} {s.label}
                  </AppText>
                </Pressable>
              ))}
            </View>
          </FieldRow>

          {/* 이름 */}
          <FieldRow label="이름">
            <Controller
              control={control}
              name="name"
              rules={{ required: '이름을 입력해 주세요', maxLength: { value: 6, message: '이름은 최대 6자까지 입력 가능해요' } }}
              render={({ field: { onChange, value } }) => (
                <FieldInput value={value} onChange={onChange} placeholder="예: 초코" maxLength={6} />
              )}
            />
            {errors.name && <AppText style={{ fontSize: 12, color: '#EF4444', marginTop: 4 }}>{errors.name.message}</AppText>}
          </FieldRow>

          {/* 생년월일 */}
          <FieldRow label="생년월일">
            <View style={{ borderWidth: 1, borderColor: '#E8E4DE', borderRadius: 12, overflow: 'hidden' }}>
              <Controller
                control={control}
                name="birthDate"
                render={({ field: { onChange, value } }) => (
                  <DrumRollDatePicker value={value} onChange={onChange} />
                )}
              />
            </View>
          </FieldRow>

          {/* 성별 */}
          <FieldRow label="성별">
            <View style={{ flexDirection: 'row', gap: 10 }}>
              {(['male', 'female'] as const).map((g) => (
                <Pressable
                  key={g}
                  onPress={() => setValue('gender', selectedGender === g ? '' : g)}
                  style={{
                    flex: 1, paddingVertical: 10, borderRadius: 12, alignItems: 'center',
                    backgroundColor: selectedGender === g ? colors.primary : '#F5F3EF',
                    borderWidth: 1,
                    borderColor: selectedGender === g ? colors.primary : '#E8E4DE',
                  }}
                >
                  <AppText style={{ fontSize: 14, color: selectedGender === g ? '#FFFFFF' : '#6B6B6B' }}>
                    {g === 'male' ? '♂ 수컷' : '♀ 암컷'}
                  </AppText>
                </Pressable>
              ))}
            </View>
          </FieldRow>

          {/* 체중 */}
          <FieldRow label="체중 (kg)">
            <Controller
              control={control}
              name="weight"
              render={({ field: { onChange, value } }) => (
                <Pressable onPress={() => openNum('체중', value, 'kg', onChange)} style={numFieldStyle}>
                  <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>{value || '예: 3.5'}</AppText>
                </Pressable>
              )}
            />
          </FieldRow>
        </SectionCard>

        {/* 추가 정보 */}
        <SectionCard title="추가 정보">
          <FieldRow label="중성화 여부">
            <View style={{ flexDirection: 'row', gap: 10 }}>
              {([true, false] as const).map((v) => {
                const isSelected = watch('neutered') === v;
                return (
                  <Pressable
                    key={String(v)}
                    onPress={() => setValue('neutered', isSelected ? null : v)}
                    style={{
                      flex: 1, paddingVertical: 10, borderRadius: 12, alignItems: 'center',
                      backgroundColor: isSelected ? colors.primary : '#F5F3EF',
                      borderWidth: 1,
                      borderColor: isSelected ? colors.primary : '#E8E4DE',
                    }}
                  >
                    <AppText style={{ fontSize: 14, color: isSelected ? '#FFFFFF' : '#6B6B6B' }}>
                      {v ? '완료' : '미완료'}
                    </AppText>
                  </Pressable>
                );
              })}
            </View>
          </FieldRow>

          <FieldRow label="동물 등록번호">
            <Controller
              control={control}
              name="animalRegistrationNumber"
              render={({ field: { onChange, value } }) => (
                <Pressable onPress={() => openNum('동물 등록번호', value, undefined, onChange, false)} style={numFieldStyle}>
                  <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>{value || '15자리 번호'}</AppText>
                </Pressable>
              )}
            />
          </FieldRow>

          <FieldRow label="질병">
            <Controller
              control={control}
              name="diseases"
              render={({ field: { onChange, value } }) => (
                <MemoInput value={value} onChange={onChange} placeholder="예: 슬개골 탈구" />
              )}
            />
          </FieldRow>

          <View style={{ marginBottom: 0 }}>
            <AppText bold style={{ fontSize: 13, color: '#3A3A3A', marginBottom: 8 }}>특이사항</AppText>
            <Controller
              control={control}
              name="specialNotes"
              render={({ field: { onChange, value } }) => (
                <MemoInput value={value} onChange={onChange} placeholder="예: 알러지, 임신 중" />
              )}
            />
          </View>
        </SectionCard>

        {/* 완료 버튼 */}
        <Pressable
          onPress={handleSubmit(onSubmit)}
          style={{
            backgroundColor: colors.primary, borderRadius: 16,
            paddingVertical: 16, alignItems: 'center', marginTop: 8,
          }}
        >
          <AppText bold style={{ color: '#FFFFFF', fontSize: 15 }}>정보 수정 완료</AppText>
        </Pressable>
      </ScrollView>

      <NumericInputModal
        visible={numpadConfig !== null}
        label={numpadConfig?.label}
        unit={numpadConfig?.unit}
        initialValue={numpadConfig?.value ?? ''}
        allowDecimal={numpadConfig?.allowDecimal}
        onConfirm={(v) => { numpadConfig?.onConfirm(v); setNumpadConfig(null); }}
        onCancel={() => setNumpadConfig(null)}
      />
    </KeyboardAvoidingView>
  );
}
