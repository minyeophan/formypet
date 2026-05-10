import { Alert, KeyboardAvoidingView, Platform, Pressable, ScrollView, TextInput, View } from 'react-native';
import { Controller, useForm } from 'react-hook-form';
import { useLocalSearchParams, router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import Toast from 'react-native-toast-message';
import { useEffect, useRef, useState } from 'react';
import BottomSheet, { BottomSheetBackdrop, BottomSheetView } from '@gorhom/bottom-sheet';
import { usePets } from '@/src/lib/pet-context';
import { QUICK_TYPES } from '@/src/lib/record-types';
import { formatDate } from '@/src/lib/utils';
import { colors } from '@/src/lib/colors';
import AppText from '@/src/components/shared/AppText';
import { showSuccessToast } from '@/src/components/shared/AppToast';
import NumericInputModal from '@/src/components/shared/NumericInputModal';
import MemoInput from '@/src/components/shared/MemoInput';
import DrumRollTimePicker, { formatTime12h } from '@/src/components/shared/DrumRollTimePicker';
import DrumRollDatePicker from '@/src/components/shared/DrumRollDatePicker';
import { ActivityRecord } from '@/src/types';

// ── 공용 UI ──────────────────────────────────────────────

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <View style={{ marginBottom: 16 }}>
      <AppText bold style={{ fontSize: 13, color: '#3A3A3A', marginBottom: 8 }}>{label}</AppText>
      {children}
    </View>
  );
}

function FieldInput({ value, onChange, placeholder, keyboardType }: {
  value: string; onChange: (v: string) => void; placeholder?: string; keyboardType?: any;
}) {
  const [focused, setFocused] = useState(false);
  return (
    <TextInput
      value={value} onChangeText={onChange}
      placeholder={placeholder} placeholderTextColor="#B0A99F" keyboardType={keyboardType}
      returnKeyType="done" blurOnSubmit
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      style={{
        backgroundColor: '#F5F3EF', borderWidth: 1.5,
        borderColor: focused ? colors.primary : '#F5F3EF',
        borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12,
        fontSize: 15, color: '#1A1A1A',
      }}
    />
  );
}

function ToggleGroup<T extends string>({
  options, value, onChange,
}: {
  options: { value: T; label: string; emoji?: string }[];
  value: T | undefined;
  onChange: (v: T | undefined) => void;
}) {
  return (
    <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap' }}>
      {options.map((o) => {
        const selected = value === o.value;
        return (
          <Pressable
            key={o.value}
            onPress={() => onChange(selected ? undefined : o.value)}
            style={{
              paddingHorizontal: 12, paddingVertical: 8, borderRadius: 20,
              backgroundColor: selected ? colors.primary : '#F5F3EF',
              borderWidth: 1, borderColor: selected ? colors.primary : '#E8E4DE',
              flexDirection: 'row', alignItems: 'center', gap: 4,
            }}
          >
            {o.emoji ? <AppText style={{ fontSize: 14 }}>{o.emoji}</AppText> : null}
            <AppText style={{ fontSize: 13, color: selected ? '#FFFFFF' : '#3A3A3A' }}>{o.label}</AppText>
          </Pressable>
        );
      })}
    </View>
  );
}

const POOP_COLORS: { value: NonNullable<ActivityRecord['poopColor']>; label: string; hex: string }[] = [
  { value: 'yellow', label: '노랑', hex: '#F5C842' },
  { value: 'lightBrown', label: '연한갈색', hex: '#C8956C' },
  { value: 'brown', label: '갈색', hex: '#8B5E3C' },
  { value: 'darkBrown', label: '진한갈색', hex: '#4A2C0A' },
  { value: 'black', label: '검은색', hex: '#1A1A1A' },
  { value: 'red', label: '붉은색', hex: '#E53E3E' },
  { value: 'green', label: '녹색', hex: '#48BB78' },
  { value: 'other', label: '기타', hex: '#D1D5DB' },
];

function ColorToggleGroup({
  value, onChange,
}: {
  value: ActivityRecord['poopColor'];
  onChange: (v: ActivityRecord['poopColor']) => void;
}) {
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
      {POOP_COLORS.map((c) => {
        const selected = value === c.value;
        return (
          <Pressable
            key={c.value}
            onPress={() => onChange(selected ? undefined : c.value)}
            style={{
              alignItems: 'center', gap: 4,
              borderWidth: 2,
              borderColor: selected ? colors.primary : 'transparent',
              borderRadius: 12, padding: 6,
            }}
          >
            <View style={{ width: 32, height: 32, borderRadius: 16, backgroundColor: c.hex, borderWidth: 1, borderColor: '#E8E4DE' }} />
            <AppText style={{ fontSize: 10, color: selected ? colors.primary : '#6B6B6B' }}>{c.label}</AppText>
          </Pressable>
        );
      })}
    </View>
  );
}

// ── 폼 타입 ──────────────────────────────────────────────

interface FormValues {
  time: string;
  note: string;
  weight: string;
  // 식사
  servedAmount: string;
  consumeMode: 'percent' | 'direct';
  consumedPercent: string;
  consumedAmount: string;
  brand: string;
  product: string;
  // 음수
  waterAmount: string;
  // 투약
  medicineName: string;
  ingredients: string;
  dosage: string;
  // 산책/수면/놀이
  distance: string;
  duration: string;
  // 병원
  vetClinicName: string;
  vetDiagnosis: string;
  vetTreatment: string;
  vetCost: string;
}

function formValuesFromRecord(record?: ActivityRecord | null): FormValues {
  return {
    time: record?.time ?? '',
    note: record?.note ?? '',
    weight: record?.weight != null ? String(record.weight) : '',
    servedAmount: record?.servedAmount != null ? String(record.servedAmount) : '',
    consumeMode: record?.consumedPercent != null ? 'percent' : 'direct',
    consumedPercent: record?.consumedPercent != null ? String(record.consumedPercent) : '',
    consumedAmount: record?.consumedAmount != null ? String(record.consumedAmount) : '',
    brand: record?.brand ?? '',
    product: record?.product ?? '',
    waterAmount: record?.amount != null ? String(record.amount) : '',
    medicineName: record?.medicineName ?? '',
    ingredients: record?.ingredients ?? '',
    dosage: record?.dosage ?? '',
    distance: record?.distance != null ? String(record.distance) : '',
    duration: record?.duration != null ? String(record.duration) : '',
    vetClinicName: record?.vetClinicName ?? '',
    vetDiagnosis: record?.vetDiagnosis ?? '',
    vetTreatment: record?.vetTreatment ?? '',
    vetCost: record?.vetCost != null ? String(record.vetCost) : '',
  };
}

// ── 메인 화면 ──────────────────────────────────────────────

export default function RecordEditScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const insets = useSafeAreaInsets();
  const { records, updateRecord, deleteRecord } = usePets();
  const liveRecord = records.find((r) => r.id === id);
  const [recordSnapshot, setRecordSnapshot] = useState<ActivityRecord | null>(() => liveRecord ?? null);
  const [isSaving, setIsSaving] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const record = liveRecord ?? recordSnapshot;

  useEffect(() => {
    if (liveRecord) setRecordSnapshot(liveRecord);
  }, [liveRecord]);

  // 배변 필드 (react-hook-form 외부로 관리)
  const [poopShape, setPoopShape] = useState<ActivityRecord['poopShape']>(record?.poopShape);
  const [poopColor, setPoopColor] = useState<ActivityRecord['poopColor']>(record?.poopColor);
  const [poopAmount, setPoopAmount] = useState<ActivityRecord['poopAmount']>(record?.poopAmount);
  const [poopSmell, setPoopSmell] = useState<ActivityRecord['poopSmell']>(record?.poopSmell);
  // 식사 foodType/feedingMethod
  const [foodType, setFoodType] = useState<ActivityRecord['foodType']>(record?.foodType);
  const [feedingMethod, setFeedingMethod] = useState<ActivityRecord['feedingMethod']>(record?.feedingMethod);
  const [showMealExtra, setShowMealExtra] = useState(!!(record?.brand || record?.product));
  // 병원
  const [vetVisitReason, setVetVisitReason] = useState<ActivityRecord['vetVisitReason']>(record?.vetVisitReason);
  const [vetNextVisitDate, setVetNextVisitDate] = useState<string | undefined>(record?.vetNextVisitDate);
  const [showVetDate, setShowVetDate] = useState(false);

  const timeSheetRef = useRef<BottomSheet>(null);
  const [pendingTime, setPendingTime] = useState('09:00');
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

  const { control, handleSubmit, watch, setValue, reset } = useForm<FormValues>({
    defaultValues: formValuesFromRecord(record),
  });

  useEffect(() => {
    if (!record) return;
    reset(formValuesFromRecord(record));
    setPoopShape(record.poopShape);
    setPoopColor(record.poopColor);
    setPoopAmount(record.poopAmount);
    setPoopSmell(record.poopSmell);
    setFoodType(record.foodType);
    setFeedingMethod(record.feedingMethod);
    setShowMealExtra(!!(record.brand || record.product));
    setVetVisitReason(record.vetVisitReason);
    setVetNextVisitDate(record.vetNextVisitDate);
    setShowVetDate(false);
  }, [record, reset]);

  if (!record) {
    return <View style={{ flex: 1, backgroundColor: '#F5F3EF' }} />;
  }

  const rec = record;
  const typeInfo = QUICK_TYPES.find((t) => t.id === rec.typeId);
  const consumeMode = watch('consumeMode');

  async function onSubmit(data: FormValues) {
    if (isSaving || isDeleting) return;
    const updates: Partial<Omit<ActivityRecord, 'id'>> = {
      time: data.time.trim() || undefined,
      note: data.note.trim() || undefined,
    };

    if (rec.typeId === 'weight') {
      updates.weight = data.weight ? parseFloat(data.weight) : undefined;
    }
    if (rec.typeId === 'meal') {
      updates.foodType = foodType;
      updates.feedingMethod = feedingMethod;
      updates.servedAmount = data.servedAmount ? parseFloat(data.servedAmount) : undefined;
      updates.consumedPercent = data.consumeMode === 'percent' && data.consumedPercent ? parseFloat(data.consumedPercent) : undefined;
      updates.consumedAmount = data.consumeMode === 'direct' && data.consumedAmount ? parseFloat(data.consumedAmount) : undefined;
      updates.brand = data.brand.trim() || undefined;
      updates.product = data.product.trim() || undefined;
    }
    if (rec.typeId === 'water') {
      updates.amount = data.waterAmount ? parseFloat(data.waterAmount) : undefined;
    }
    if (rec.typeId === 'medicine') {
      updates.medicineName = data.medicineName.trim() || undefined;
      updates.ingredients = data.ingredients.trim() || undefined;
      updates.dosage = data.dosage.trim() || undefined;
    }
    if (rec.typeId === 'poop') {
      updates.poopShape = poopShape;
      updates.poopColor = poopColor;
      updates.poopAmount = poopAmount;
      updates.poopSmell = poopSmell;
    }
    if (rec.typeId === 'walk') {
      updates.distance = data.distance ? parseFloat(data.distance) : undefined;
      updates.duration = data.duration ? parseFloat(data.duration) : undefined;
    }
    if (rec.typeId === 'sleep' || rec.typeId === 'play') {
      updates.duration = data.duration ? parseFloat(data.duration) : undefined;
    }
    if (rec.typeId === 'vet') {
      updates.vetClinicName = data.vetClinicName.trim() || undefined;
      updates.vetVisitReason = vetVisitReason;
      updates.vetDiagnosis = data.vetDiagnosis.trim() || undefined;
      updates.vetTreatment = data.vetTreatment.trim() || undefined;
      updates.vetCost = data.vetCost ? parseFloat(data.vetCost) : undefined;
      updates.vetNextVisitDate = vetNextVisitDate;
    }

    try {
      setIsSaving(true);
      await updateRecord(id, updates);
      setRecordSnapshot((prev) => prev ? { ...prev, ...updates } : prev);
      showSuccessToast('기록 수정 완료');
      router.back();
    } catch (error) {
      setIsSaving(false);
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : 'Update failed' });
    }
  }

  function confirmDelete() {
    if (isSaving || isDeleting) return;
    Alert.alert('기록 삭제', '이 기록을 삭제할까요?', [
      { text: '취소', style: 'cancel' },
      {
        text: '삭제',
        style: 'destructive',
        onPress: async () => {
          try {
            setIsDeleting(true);
            await deleteRecord(id);
            showSuccessToast('기록 삭제 완료');
            router.back();
          } catch (error) {
            setIsDeleting(false);
            Toast.show({ type: 'error', text1: error instanceof Error ? error.message : 'Delete failed' });
          }
        },
      },
    ]);
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
          <AppText bold style={{ fontSize: 17, color: '#1A1A1A' }}>기록 수정</AppText>
        </View>
      </View>

      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 16, paddingBottom: 40 }} keyboardShouldPersistTaps="handled" keyboardDismissMode="on-drag">
        {/* 타입 표시 */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, backgroundColor: '#FFFFFF', borderRadius: 16, padding: 16, marginBottom: 12 }}>
          <View style={{ width: 44, height: 44, borderRadius: 12, backgroundColor: typeInfo?.bg ?? '#F5F3EF', alignItems: 'center', justifyContent: 'center' }}>
            <AppText style={{ fontSize: 22 }}>{typeInfo?.emoji ?? '📝'}</AppText>
          </View>
          <View>
            <AppText bold style={{ fontSize: 15, color: '#1A1A1A' }}>{typeInfo?.label ?? rec.typeId}</AppText>
            <AppText style={{ fontSize: 12, color: '#B0A99F' }}>{formatDate(rec.date)}</AppText>
          </View>
        </View>

        <View style={{ backgroundColor: '#FFFFFF', borderRadius: 16, padding: 16 }}>
          {/* 시간 */}
          <Field label="시간 (선택)">
            <Controller control={control} name="time"
              render={({ field: { onChange, value } }) => (
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                  <Pressable
                    onPress={() => { setPendingTime(value || '09:00'); timeSheetRef.current?.expand(); }}
                    style={[numFieldStyle, { flex: 1, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }]}
                  >
                    <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>
                      {value ? formatTime12h(value) : '시간 선택'}
                    </AppText>
                    <Ionicons name="time-outline" size={16} color="#B0A99F" />
                  </Pressable>
                  {value ? (
                    <Pressable onPress={() => onChange('')}>
                      <Ionicons name="close-circle" size={20} color="#B0A99F" />
                    </Pressable>
                  ) : null}
                </View>
              )} />
          </Field>

          {/* ── 식사 ── */}
          {rec.typeId === 'meal' && (
            <>
              <Field label="사료 종류">
                <ToggleGroup
                  options={[
                    { value: 'dry' as const, label: '건식', emoji: '🥣' },
                    { value: 'wet' as const, label: '습식', emoji: '🥫' },
                    { value: 'treat' as const, label: '간식', emoji: '🍖' },
                    { value: 'prescription' as const, label: '처방식', emoji: '💊' },
                    { value: 'raw' as const, label: '생식', emoji: '🥩' },
                    { value: 'freezeDried' as const, label: '동결건조', emoji: '❄️' },
                    { value: 'other' as const, label: '기타', emoji: '🍽️' },
                  ]}
                  value={foodType}
                  onChange={setFoodType}
                />
              </Field>
              <Field label="급식 방법">
                <ToggleGroup
                  options={[
                    { value: 'hand' as const, label: '배식' },
                    { value: 'free' as const, label: '자율급식' },
                    { value: 'autoFeeder' as const, label: '자동급식기' },
                    { value: 'other' as const, label: '기타' },
                  ]}
                  value={feedingMethod}
                  onChange={setFeedingMethod}
                />
              </Field>
              <Field label="급여량 (g)">
                <Controller control={control} name="servedAmount"
                  render={({ field: { onChange, value } }) => (
                    <Pressable onPress={() => openNum('급여량', value, 'g', onChange)} style={numFieldStyle}>
                      <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>{value || '예: 100'}</AppText>
                    </Pressable>
                  )} />
              </Field>
              <Field label="섭취량">
                <View style={{ flexDirection: 'row', gap: 8, marginBottom: 8 }}>
                  {(['percent', 'direct'] as const).map((m) => (
                    <Pressable
                      key={m}
                      onPress={() => setValue('consumeMode', m)}
                      style={{
                        paddingHorizontal: 14, paddingVertical: 7, borderRadius: 20,
                        backgroundColor: consumeMode === m ? colors.primary : '#F5F3EF',
                        borderWidth: 1, borderColor: consumeMode === m ? colors.primary : '#E8E4DE',
                      }}
                    >
                      <AppText style={{ fontSize: 13, color: consumeMode === m ? '#FFFFFF' : '#3A3A3A' }}>
                        {m === 'percent' ? '% 입력' : '직접 입력 (g)'}
                      </AppText>
                    </Pressable>
                  ))}
                </View>
                <Controller
                  control={control}
                  name={consumeMode === 'percent' ? 'consumedPercent' : 'consumedAmount'}
                  render={({ field: { onChange, value } }) => (
                    <Pressable onPress={() => openNum('섭취량', value, consumeMode === 'percent' ? '%' : 'g', onChange)} style={numFieldStyle}>
                      <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>
                        {value || (consumeMode === 'percent' ? '예: 80 (%)' : '예: 80 (g)')}
                      </AppText>
                    </Pressable>
                  )} />
              </Field>
              <Pressable
                onPress={() => setShowMealExtra((v) => !v)}
                style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 10 }}
              >
                <AppText style={{ fontSize: 13, color: colors.primary }}>추가 정보 (브랜드·제품명)</AppText>
                <Ionicons name={showMealExtra ? 'chevron-up' : 'chevron-down'} size={14} color={colors.primary} />
              </Pressable>
              {showMealExtra && (
                <>
                  <Field label="브랜드명">
                    <Controller control={control} name="brand"
                      render={({ field: { onChange, value } }) => (
                        <FieldInput value={value} onChange={onChange} placeholder="예: 로얄캐닌" />
                      )} />
                  </Field>
                  <Field label="제품명">
                    <Controller control={control} name="product"
                      render={({ field: { onChange, value } }) => (
                        <FieldInput value={value} onChange={onChange} placeholder="예: 미니 어덜트" />
                      )} />
                  </Field>
                </>
              )}
            </>
          )}

          {/* ── 음수 ── */}
          {rec.typeId === 'water' && (
            <Field label="양 (ml)">
              <Controller control={control} name="waterAmount"
                render={({ field: { onChange, value } }) => (
                  <Pressable onPress={() => openNum('음수량', value, 'ml', onChange)} style={numFieldStyle}>
                    <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>{value || '예: 150'}</AppText>
                  </Pressable>
                )} />
            </Field>
          )}

          {/* ── 투약 ── */}
          {rec.typeId === 'medicine' && (
            <>
              <Field label="약 이름">
                <Controller control={control} name="medicineName"
                  render={({ field: { onChange, value } }) => (
                    <FieldInput value={value} onChange={onChange} placeholder="예: 항생제" />
                  )} />
              </Field>
              <Field label="성분">
                <Controller control={control} name="ingredients"
                  render={({ field: { onChange, value } }) => (
                    <FieldInput value={value} onChange={onChange} placeholder="예: 아목시실린" />
                  )} />
              </Field>
              <Field label="용량">
                <Controller control={control} name="dosage"
                  render={({ field: { onChange, value } }) => (
                    <FieldInput value={value} onChange={onChange} placeholder="예: 1정" />
                  )} />
              </Field>
            </>
          )}

          {/* ── 배변 ── */}
          {rec.typeId === 'poop' && (
            <>
              <Field label="모양">
                <ToggleGroup
                  options={[
                    { value: 'normal' as const, label: '정상', emoji: '💩' },
                    { value: 'soft' as const, label: '묽음', emoji: '🫠' },
                    { value: 'hard' as const, label: '딱딱함', emoji: '🪨' },
                    { value: 'pellet' as const, label: '과립형', emoji: '🫘' },
                    { value: 'thin' as const, label: '가는변', emoji: '🎀' },
                    { value: 'liquid' as const, label: '액체', emoji: '💦' },
                  ]}
                  value={poopShape}
                  onChange={setPoopShape}
                />
              </Field>
              <Field label="색상">
                <ColorToggleGroup value={poopColor} onChange={setPoopColor} />
              </Field>
              <Field label="양">
                <ToggleGroup
                  options={[
                    { value: 'small' as const, label: '소' },
                    { value: 'normal' as const, label: '보통' },
                    { value: 'large' as const, label: '다량' },
                  ]}
                  value={poopAmount}
                  onChange={setPoopAmount}
                />
              </Field>
              <Field label="냄새">
                <ToggleGroup
                  options={[
                    { value: 'none' as const, label: '없음', emoji: '😊' },
                    { value: 'mild' as const, label: '약함', emoji: '🙂' },
                    { value: 'strong' as const, label: '강함', emoji: '😣' },
                    { value: 'veryStrong' as const, label: '매우강함', emoji: '🤢' },
                  ]}
                  value={poopSmell}
                  onChange={setPoopSmell}
                />
              </Field>
            </>
          )}

          {/* ── 병원 ── */}
          {rec.typeId === 'vet' && (
            <>
              <Field label="병원명">
                <Controller control={control} name="vetClinicName"
                  render={({ field: { onChange, value } }) => (
                    <FieldInput value={value} onChange={onChange} placeholder="예: 행복동물병원" />
                  )} />
              </Field>
              <Field label="방문 목적">
                <ToggleGroup
                  options={[
                    { value: 'checkup' as const, label: '정기검진' },
                    { value: 'vaccination' as const, label: '예방접종' },
                    { value: 'treatment' as const, label: '치료' },
                    { value: 'surgery' as const, label: '수술' },
                    { value: 'other' as const, label: '기타' },
                  ]}
                  value={vetVisitReason}
                  onChange={setVetVisitReason}
                />
              </Field>
              <Field label="진단 내용">
                <Controller control={control} name="vetDiagnosis"
                  render={({ field: { onChange, value } }) => (
                    <FieldInput value={value} onChange={onChange} placeholder="예: 슬개골 탈구 2등급" />
                  )} />
              </Field>
              <Field label="처방/치료">
                <Controller control={control} name="vetTreatment"
                  render={({ field: { onChange, value } }) => (
                    <FieldInput value={value} onChange={onChange} placeholder="예: 항생제 처방, 안정 권고" />
                  )} />
              </Field>
              <Field label="비용 (원)">
                <Controller control={control} name="vetCost"
                  render={({ field: { onChange, value } }) => (
                    <Pressable onPress={() => openNum('비용', value, '원', onChange, false)} style={numFieldStyle}>
                      <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>
                        {value ? `${value}원` : '예: 50000'}
                      </AppText>
                    </Pressable>
                  )} />
              </Field>
              <Field label="다음 방문 예정일 (선택)">
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                  <Pressable
                    onPress={() => { setVetNextVisitDate(vetNextVisitDate || new Date().toISOString().split('T')[0]); setShowVetDate((v) => !v); }}
                    style={[numFieldStyle, { flex: 1, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }]}
                  >
                    <AppText style={{ fontSize: 15, color: vetNextVisitDate ? '#1A1A1A' : '#B0A99F' }}>
                      {vetNextVisitDate || '날짜 선택 (선택)'}
                    </AppText>
                    <Ionicons name={showVetDate ? 'chevron-up' : 'chevron-down'} size={14} color="#B0A99F" />
                  </Pressable>
                  {vetNextVisitDate ? (
                    <Pressable onPress={() => { setVetNextVisitDate(undefined); setShowVetDate(false); }}>
                      <Ionicons name="close-circle" size={20} color="#B0A99F" />
                    </Pressable>
                  ) : null}
                </View>
                {showVetDate && (
                  <View style={{ borderWidth: 1, borderColor: '#E8E4DE', borderRadius: 12, overflow: 'hidden', marginTop: 8 }}>
                    <DrumRollDatePicker
                      value={vetNextVisitDate || new Date().toISOString().split('T')[0]}
                      onChange={setVetNextVisitDate}
                    />
                    <View style={{ flexDirection: 'row', gap: 8, padding: 12 }}>
                      <Pressable
                        onPress={() => setShowVetDate(false)}
                        style={{ flex: 1, paddingVertical: 10, borderRadius: 10, backgroundColor: '#F5F3EF', alignItems: 'center' }}
                      >
                        <AppText style={{ fontSize: 14 }}>취소</AppText>
                      </Pressable>
                      <Pressable
                        onPress={() => setShowVetDate(false)}
                        style={{ flex: 2, paddingVertical: 10, borderRadius: 10, backgroundColor: colors.primary, alignItems: 'center' }}
                      >
                        <AppText bold style={{ fontSize: 14, color: '#FFFFFF' }}>확인</AppText>
                      </Pressable>
                    </View>
                  </View>
                )}
              </Field>
            </>
          )}

          {/* ── 산책 ── */}
          {rec.typeId === 'walk' && (
            <>
              <Field label="거리 (m)">
                <Controller control={control} name="distance"
                  render={({ field: { onChange, value } }) => (
                    <Pressable onPress={() => openNum('거리', value, 'm', onChange)} style={numFieldStyle}>
                      <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>{value || '예: 500'}</AppText>
                    </Pressable>
                  )} />
              </Field>
              <Field label="소요시간 (분)">
                <Controller control={control} name="duration"
                  render={({ field: { onChange, value } }) => (
                    <Pressable onPress={() => openNum('소요시간', value, '분', onChange)} style={numFieldStyle}>
                      <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>{value || '예: 30'}</AppText>
                    </Pressable>
                  )} />
              </Field>
            </>
          )}

          {/* ── 수면·놀이 ── */}
          {(rec.typeId === 'sleep' || rec.typeId === 'play') && (
            <Field label="시간 (분)">
              <Controller control={control} name="duration"
                render={({ field: { onChange, value } }) => (
                  <Pressable onPress={() => openNum('시간', value, '분', onChange)} style={numFieldStyle}>
                    <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>{value || '예: 60'}</AppText>
                  </Pressable>
                )} />
            </Field>
          )}

          {/* ── 체중 ── */}
          {rec.typeId === 'weight' && (
            <Field label="체중 (kg)">
              <Controller control={control} name="weight"
                render={({ field: { onChange, value } }) => (
                  <Pressable onPress={() => openNum('체중', value, 'kg', onChange)} style={numFieldStyle}>
                    <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>{value || '예: 4.2'}</AppText>
                  </Pressable>
                )} />
            </Field>
          )}

          {/* 메모 */}
          {rec.typeId !== 'weight' && (
            <View style={{ marginBottom: 0 }}>
              <AppText bold style={{ fontSize: 13, color: '#3A3A3A', marginBottom: 8 }}>메모 (선택)</AppText>
              <Controller control={control} name="note"
                render={({ field: { onChange, value } }) => (
                  <MemoInput value={value} onChange={onChange} placeholder="간단한 메모" />
                )} />
            </View>
          )}
        </View>

        {/* 수정 완료 */}
        <Pressable
          disabled={isSaving || isDeleting}
          onPress={handleSubmit(onSubmit)}
          style={{ backgroundColor: colors.primary, borderRadius: 16, paddingVertical: 16, alignItems: 'center', marginTop: 16, opacity: isSaving || isDeleting ? 0.6 : 1 }}
        >
          <AppText bold style={{ color: '#FFFFFF', fontSize: 15 }}>{isSaving ? '저장 중...' : '수정 완료'}</AppText>
        </Pressable>

        {/* 삭제 */}
        <Pressable
          disabled={isSaving || isDeleting}
          onPress={confirmDelete}
          style={{ borderRadius: 16, paddingVertical: 14, alignItems: 'center', marginTop: 10, borderWidth: 1, borderColor: '#EF4444', opacity: isSaving || isDeleting ? 0.6 : 1 }}
        >
          <AppText bold style={{ color: '#EF4444', fontSize: 15 }}>{isDeleting ? '삭제 중...' : '기록 삭제'}</AppText>
        </Pressable>
      </ScrollView>

      {/* 시간 선택 BottomSheet */}
      <BottomSheet
        ref={timeSheetRef}
        index={-1}
        enableDynamicSizing
        enablePanDownToClose
        backdropComponent={(p) => <BottomSheetBackdrop {...p} disappearsOnIndex={-1} appearsOnIndex={0} />}
      >
        <BottomSheetView style={{ paddingHorizontal: 20, paddingBottom: 40 }}>
          <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginBottom: 16, marginTop: 8 }}>시간 선택</AppText>
          <DrumRollTimePicker value={pendingTime} onChange={setPendingTime} />
          <View style={{ flexDirection: 'row', gap: 10, marginTop: 16 }}>
            <Pressable
              onPress={() => timeSheetRef.current?.close()}
              style={{ flex: 1, paddingVertical: 13, borderRadius: 14, alignItems: 'center', backgroundColor: '#F5F3EF' }}
            >
              <AppText style={{ fontSize: 14 }}>취소</AppText>
            </Pressable>
            <Pressable
              onPress={() => { setValue('time', pendingTime); timeSheetRef.current?.close(); }}
              style={{ flex: 2, paddingVertical: 13, borderRadius: 14, alignItems: 'center', backgroundColor: colors.primary }}
            >
              <AppText bold style={{ color: '#FFFFFF', fontSize: 14 }}>확인</AppText>
            </Pressable>
          </View>
        </BottomSheetView>
      </BottomSheet>

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
