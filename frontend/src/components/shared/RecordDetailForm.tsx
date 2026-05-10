import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';
import { useState } from 'react';
import { Alert, Image, Platform, Pressable, TextInput, View } from 'react-native';
import { ActivityRecord, Routine } from '@/src/types';
import { colors } from '@/src/lib/colors';
import { todayString } from '@/src/lib/utils';
import AppText from './AppText';
import MemoInput from './MemoInput';
import NumericInputModal from './NumericInputModal';
import DrumRollDatePicker from './DrumRollDatePicker';
import BottomSheet, { BottomSheetBackdrop, BottomSheetView } from '@gorhom/bottom-sheet';
import { useRef } from 'react';

type RecordBaseKeys = 'id' | 'petId' | 'typeId' | 'date' | 'time' | 'routineId';
export type RecordDetailDraft = Partial<Omit<ActivityRecord, RecordBaseKeys>>;

let SheetTextInput: typeof TextInput = TextInput;
if (Platform.OS !== 'web') {
  SheetTextInput = require('@gorhom/bottom-sheet').BottomSheetTextInput;
}

const DETAIL_KEYS_BY_TYPE: Record<string, (keyof RecordDetailDraft)[]> = {
  meal: ['foodType', 'feedingMethod', 'servedAmount', 'consumedAmount', 'consumedPercent', 'brand', 'product', 'ingredients'],
  water: ['amount'],
  medicine: ['medicineName', 'ingredients', 'dosage'],
  poop: ['poopShape', 'poopColor', 'poopAmount', 'poopSmell', 'poopPhotos'],
  walk: ['distance', 'duration'],
  sleep: ['duration'],
  play: ['duration'],
  weight: ['weight'],
  vet: ['vetClinicName', 'vetVisitReason', 'vetDiagnosis', 'vetTreatment', 'vetCost', 'vetNextVisitDate'],
  checkup: ['vetClinicName', 'vetVisitReason', 'vetDiagnosis', 'vetTreatment', 'vetCost', 'vetNextVisitDate'],
};

const POOP_COLORS: { value: NonNullable<ActivityRecord['poopColor']>; label: string; hex: string }[] = [
  { value: 'yellow', label: '노랑', hex: '#F5C842' },
  { value: 'lightBrown', label: '연한 갈색', hex: '#C8956C' },
  { value: 'brown', label: '갈색', hex: '#8B5E3C' },
  { value: 'darkBrown', label: '진한 갈색', hex: '#4A2C0A' },
  { value: 'black', label: '검정', hex: '#1A1A1A' },
  { value: 'red', label: '빨강', hex: '#E53E3E' },
  { value: 'green', label: '초록', hex: '#48BB78' },
  { value: 'other', label: '기타', hex: '#D1D5DB' },
];

export function createEmptyRecordDetail(typeId: string): RecordDetailDraft {
  const detail: RecordDetailDraft = {};
  for (const key of DETAIL_KEYS_BY_TYPE[typeId] ?? []) {
    detail[key] = undefined;
  }
  return detail;
}

export function sanitizeRecordDetail(typeId: string, detail: RecordDetailDraft | undefined): RecordDetailDraft {
  const allowed = new Set(DETAIL_KEYS_BY_TYPE[typeId] ?? []);
  const sanitized: RecordDetailDraft = {};
  for (const key of allowed) {
    const value = detail?.[key];
    if (value === undefined || value === null || value === '') continue;
    if (Array.isArray(value) && value.length === 0) continue;
    sanitized[key] = value as never;
  }
  return sanitized;
}

export function buildRecordFromRoutineTemplate(routine: Routine, date: string, time?: string | null): Omit<ActivityRecord, 'id'> {
  const detail = sanitizeRecordDetail(routine.typeId, routine.detail);
  return {
    ...detail,
    petId: routine.petId,
    typeId: routine.typeId,
    date,
    ...(time ? { time } : {}),
    routineId: routine.id,
    ...(routine.note ? { note: routine.note } : {}),
  };
}

function valueToString(value: unknown): string {
  return value === undefined || value === null ? '' : String(value);
}

function numberValue(value: string): number | undefined {
  return value.trim() ? Number(value) : undefined;
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <View style={{ marginBottom: 14 }}>
      <AppText bold style={{ fontSize: 13, color: '#6B6B6B', marginBottom: 6 }}>{label}</AppText>
      {children}
    </View>
  );
}

function TextF({ value, onChange, placeholder, maxLength }: {
  value: string; onChange: (v: string) => void; placeholder?: string; maxLength?: number;
}) {
  const [focused, setFocused] = useState(false);
  return (
    <SheetTextInput
      value={value}
      onChangeText={onChange}
      placeholder={placeholder}
      placeholderTextColor="#B0A99F"
      maxLength={maxLength}
      returnKeyType="done"
      blurOnSubmit
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      style={{
        backgroundColor: '#F5F3EF',
        borderRadius: 12,
        borderWidth: 1.5,
        borderColor: focused ? colors.primary : '#F5F3EF',
        paddingHorizontal: 16,
        paddingVertical: 11,
        fontSize: 15,
        color: '#1A1A1A',
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
              paddingHorizontal: 12,
              paddingVertical: 8,
              borderRadius: 20,
              backgroundColor: selected ? colors.primary : '#F5F3EF',
              borderWidth: 1,
              borderColor: selected ? colors.primary : '#E8E4DE',
              flexDirection: 'row',
              alignItems: 'center',
              gap: 4,
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
              alignItems: 'center',
              gap: 4,
              borderWidth: 2,
              borderColor: selected ? colors.primary : 'transparent',
              borderRadius: 12,
              padding: 6,
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

interface Props {
  typeId: string;
  detail: RecordDetailDraft;
  onChange: (detail: RecordDetailDraft) => void;
  note?: string;
  onNoteChange?: (note: string) => void;
  includeNote?: boolean;
  includePoopPhotos?: boolean;
  inBottomSheet?: boolean;
  onMemoFocus?: () => void;
}

export default function RecordDetailForm({
  typeId,
  detail,
  onChange,
  note = '',
  onNoteChange,
  includeNote = true,
  includePoopPhotos = true,
  inBottomSheet = false,
  onMemoFocus,
}: Props) {
  const vetDateSheetRef = useRef<BottomSheet>(null);
  const [consumeMode, setConsumeMode] = useState<'percent' | 'direct'>(detail.consumedAmount ? 'direct' : 'percent');
  const [showMealExtra, setShowMealExtra] = useState(Boolean(detail.brand || detail.product));
  const [pendingVetNextVisitDate, setPendingVetNextVisitDate] = useState(detail.vetNextVisitDate ?? todayString());
  const [vetDatePickerOpen, setVetDatePickerOpen] = useState(false);
  const [numpadConfig, setNumpadConfig] = useState<{
    label: string;
    unit?: string;
    value: string;
    onConfirm: (v: string) => void;
    allowDecimal?: boolean;
  } | null>(null);

  function patch(next: RecordDetailDraft) {
    onChange({ ...detail, ...next });
  }

  function openNum(label: string, value: unknown, unit: string | undefined, onConfirm: (v: string) => void, allowDecimal = true) {
    setNumpadConfig({ label, unit, value: valueToString(value), onConfirm, allowDecimal });
  }

  async function pickPhoto() {
    const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (status !== 'granted') {
      Alert.alert('사진 접근 권한', '설정에서 사진 접근을 허용해 주세요.');
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      quality: 0.7,
    });
    if (!result.canceled && result.assets[0]) {
      patch({ poopPhotos: [...(detail.poopPhotos ?? []), result.assets[0].uri].slice(0, 3) });
    }
  }

  return (
    <>
      {typeId === 'meal' && (
        <>
          <Field label="사료 종류">
            <ToggleGroup
              options={[
                { value: 'dry' as const, label: '건식', emoji: '🥣' },
                { value: 'wet' as const, label: '습식', emoji: '🥫' },
                { value: 'treat' as const, label: '간식', emoji: '🦴' },
                { value: 'prescription' as const, label: '처방식', emoji: '💊' },
                { value: 'raw' as const, label: '생식', emoji: '🥩' },
                { value: 'freezeDried' as const, label: '동결건조', emoji: '❄️' },
                { value: 'other' as const, label: '기타', emoji: '·' },
              ]}
              value={detail.foodType}
              onChange={(foodType) => patch({ foodType })}
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
              value={detail.feedingMethod}
              onChange={(feedingMethod) => patch({ feedingMethod })}
            />
          </Field>
          <Field label="급여량 (g)">
            <Pressable onPress={() => openNum('급여량', detail.servedAmount, 'g', (v) => patch({ servedAmount: numberValue(v) }))}
              style={{ backgroundColor: '#F5F3EF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 11, minHeight: 44, justifyContent: 'center' }}>
              <AppText style={{ fontSize: 15, color: detail.servedAmount ? '#1A1A1A' : '#B0A99F' }}>{valueToString(detail.servedAmount) || '예: 100'}</AppText>
            </Pressable>
          </Field>
          <Field label="섭취량">
            <View style={{ flexDirection: 'row', gap: 8, marginBottom: 8 }}>
              {(['percent', 'direct'] as const).map((m) => (
                <Pressable
                  key={m}
                  onPress={() => setConsumeMode(m)}
                  style={{
                    paddingHorizontal: 14,
                    paddingVertical: 7,
                    borderRadius: 20,
                    backgroundColor: consumeMode === m ? colors.primary : '#F5F3EF',
                    borderWidth: 1,
                    borderColor: consumeMode === m ? colors.primary : '#E8E4DE',
                  }}
                >
                  <AppText style={{ fontSize: 13, color: consumeMode === m ? '#FFFFFF' : '#3A3A3A' }}>
                    {m === 'percent' ? '% 입력' : '직접 입력 (g)'}
                  </AppText>
                </Pressable>
              ))}
            </View>
            <Pressable
              onPress={() => {
                const isPercent = consumeMode === 'percent';
                openNum(
                  '섭취량',
                  isPercent ? detail.consumedPercent : detail.consumedAmount,
                  isPercent ? '%' : 'g',
                  (v) => patch(isPercent ? { consumedPercent: numberValue(v), consumedAmount: undefined } : { consumedAmount: numberValue(v), consumedPercent: undefined }),
                );
              }}
              style={{ backgroundColor: '#F5F3EF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 11, minHeight: 44, justifyContent: 'center' }}>
              <AppText style={{ fontSize: 15, color: (consumeMode === 'percent' ? detail.consumedPercent : detail.consumedAmount) ? '#1A1A1A' : '#B0A99F' }}>
                {valueToString(consumeMode === 'percent' ? detail.consumedPercent : detail.consumedAmount) || (consumeMode === 'percent' ? '예: 80 (%)' : '예: 80 (g)')}
              </AppText>
            </Pressable>
          </Field>
          <Pressable
            onPress={() => setShowMealExtra((v) => !v)}
            style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 10 }}
          >
            <AppText style={{ fontSize: 13, color: colors.primary }}>추가 정보 (브랜드/제품명)</AppText>
            <Ionicons name={showMealExtra ? 'chevron-up' : 'chevron-down'} size={14} color={colors.primary} />
          </Pressable>
          {showMealExtra && (
            <>
              <Field label="브랜드명">
                <TextF value={detail.brand ?? ''} onChange={(brand) => patch({ brand })} placeholder="예: 로얄캐닌" />
              </Field>
              <Field label="제품명">
                <TextF value={detail.product ?? ''} onChange={(product) => patch({ product })} placeholder="예: 미니 인도어" />
              </Field>
            </>
          )}
        </>
      )}

      {typeId === 'water' && (
        <Field label="양 (ml)">
          <Pressable onPress={() => openNum('음수량', detail.amount, 'ml', (v) => patch({ amount: numberValue(v) }))}
            style={{ backgroundColor: '#F5F3EF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 11, minHeight: 44, justifyContent: 'center' }}>
            <AppText style={{ fontSize: 15, color: detail.amount ? '#1A1A1A' : '#B0A99F' }}>{valueToString(detail.amount) || '예: 150'}</AppText>
          </Pressable>
        </Field>
      )}

      {typeId === 'medicine' && (
        <>
          <Field label="약 이름">
            <TextF value={detail.medicineName ?? ''} onChange={(medicineName) => patch({ medicineName })} placeholder="예: 약 이름" />
          </Field>
          <Field label="성분">
            <TextF value={detail.ingredients ?? ''} onChange={(ingredients) => patch({ ingredients })} placeholder="예: 성분" />
          </Field>
          <Field label="용량">
            <TextF value={detail.dosage ?? ''} onChange={(dosage) => patch({ dosage })} placeholder="예: 1정" />
          </Field>
        </>
      )}

      {typeId === 'poop' && (
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
              value={detail.poopShape}
              onChange={(poopShape) => patch({ poopShape })}
            />
          </Field>
          <Field label="색상">
            <ColorToggleGroup value={detail.poopColor} onChange={(poopColor) => patch({ poopColor })} />
          </Field>
          <Field label="양">
            <ToggleGroup
              options={[
                { value: 'small' as const, label: '소량' },
                { value: 'normal' as const, label: '보통' },
                { value: 'large' as const, label: '다량' },
              ]}
              value={detail.poopAmount}
              onChange={(poopAmount) => patch({ poopAmount })}
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
              value={detail.poopSmell}
              onChange={(poopSmell) => patch({ poopSmell })}
            />
          </Field>
          {includePoopPhotos && (
            <Field label={`사진 (${detail.poopPhotos?.length ?? 0}/3)`}>
              <View style={{ flexDirection: 'row', gap: 8 }}>
                {(detail.poopPhotos ?? []).map((uri, i) => (
                  <Pressable
                    key={uri}
                    onPress={() => patch({ poopPhotos: (detail.poopPhotos ?? []).filter((_, idx) => idx !== i) })}
                    style={{ position: 'relative' }}
                  >
                    <Image source={{ uri }} style={{ width: 80, height: 80, borderRadius: 10 }} />
                    <View style={{
                      position: 'absolute',
                      top: -6,
                      right: -6,
                      backgroundColor: '#EF4444',
                      borderRadius: 10,
                      width: 20,
                      height: 20,
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}>
                      <Ionicons name="close" size={14} color="#FFFFFF" />
                    </View>
                  </Pressable>
                ))}
                {(detail.poopPhotos?.length ?? 0) < 3 && (
                  <Pressable
                    onPress={pickPhoto}
                    style={{
                      width: 80,
                      height: 80,
                      borderRadius: 10,
                      backgroundColor: '#F5F3EF',
                      borderWidth: 1.5,
                      borderStyle: 'dashed',
                      borderColor: '#D4CFC8',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: 4,
                    }}
                  >
                    <Ionicons name="camera-outline" size={22} color="#B0A99F" />
                    <AppText style={{ fontSize: 11, color: '#B0A99F' }}>추가</AppText>
                  </Pressable>
                )}
              </View>
            </Field>
          )}
        </>
      )}

      {(typeId === 'vet' || typeId === 'checkup') && (
        <>
          <Field label="병원명">
            <TextF value={detail.vetClinicName ?? ''} onChange={(vetClinicName) => patch({ vetClinicName })} placeholder="예: 행복동물병원" />
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
              value={detail.vetVisitReason}
              onChange={(vetVisitReason) => patch({ vetVisitReason })}
            />
          </Field>
          <Field label="진단 내용">
            <TextF value={detail.vetDiagnosis ?? ''} onChange={(vetDiagnosis) => patch({ vetDiagnosis })} placeholder="예: 슬개골 탈구 2단계" />
          </Field>
          <Field label="처방/치료">
            <TextF value={detail.vetTreatment ?? ''} onChange={(vetTreatment) => patch({ vetTreatment })} placeholder="예: 약 처방, 안정 권고" />
          </Field>
          <Field label="비용 (원)">
            <Pressable
              onPress={() => openNum('비용', detail.vetCost, '원', (v) => patch({ vetCost: numberValue(v) }), false)}
              style={{ backgroundColor: '#F5F3EF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 11, minHeight: 44, justifyContent: 'center' }}
            >
              <AppText style={{ fontSize: 15, color: detail.vetCost ? '#1A1A1A' : '#B0A99F' }}>
                {detail.vetCost ? `${detail.vetCost}원` : '예: 50000'}
              </AppText>
            </Pressable>
          </Field>
          <Field label="다음 방문 예정일 (선택)">
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
              <Pressable
                onPress={() => {
                  setPendingVetNextVisitDate(detail.vetNextVisitDate || todayString());
                  setVetDatePickerOpen(true);
                }}
                style={{
                  flex: 1,
                  backgroundColor: '#F5F3EF',
                  borderRadius: 12,
                  paddingHorizontal: 16,
                  paddingVertical: 11,
                  flexDirection: 'row',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                }}
              >
                <AppText style={{ fontSize: 15, color: detail.vetNextVisitDate ? '#1A1A1A' : '#B0A99F' }}>
                  {detail.vetNextVisitDate || '예: 2026-06-01'}
                </AppText>
                <Ionicons name="calendar-outline" size={14} color="#B0A99F" />
              </Pressable>
              {detail.vetNextVisitDate ? (
                <Pressable onPress={() => patch({ vetNextVisitDate: undefined })}>
                  <Ionicons name="close-circle" size={20} color="#B0A99F" />
                </Pressable>
              ) : null}
            </View>
          </Field>
        </>
      )}

      {typeId === 'walk' && (
        <>
          <Field label="거리 (m)">
            <Pressable onPress={() => openNum('거리', detail.distance, 'm', (v) => patch({ distance: numberValue(v) }))}
              style={{ backgroundColor: '#F5F3EF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 11, minHeight: 44, justifyContent: 'center' }}>
              <AppText style={{ fontSize: 15, color: detail.distance ? '#1A1A1A' : '#B0A99F' }}>{valueToString(detail.distance) || '예: 500'}</AppText>
            </Pressable>
          </Field>
          <Field label="소요시간 (분)">
            <Pressable onPress={() => openNum('소요시간', detail.duration, '분', (v) => patch({ duration: numberValue(v) }))}
              style={{ backgroundColor: '#F5F3EF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 11, minHeight: 44, justifyContent: 'center' }}>
              <AppText style={{ fontSize: 15, color: detail.duration ? '#1A1A1A' : '#B0A99F' }}>{valueToString(detail.duration) || '예: 30'}</AppText>
            </Pressable>
          </Field>
        </>
      )}

      {(typeId === 'sleep' || typeId === 'play') && (
        <Field label="시간 (분)">
          <Pressable onPress={() => openNum('시간', detail.duration, '분', (v) => patch({ duration: numberValue(v) }))}
            style={{ backgroundColor: '#F5F3EF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 11, minHeight: 44, justifyContent: 'center' }}>
            <AppText style={{ fontSize: 15, color: detail.duration ? '#1A1A1A' : '#B0A99F' }}>{valueToString(detail.duration) || '예: 60'}</AppText>
          </Pressable>
        </Field>
      )}

      {typeId === 'weight' && (
        <Field label="체중 (kg)">
          <Pressable onPress={() => openNum('체중', detail.weight, 'kg', (v) => patch({ weight: numberValue(v) }))}
            style={{ backgroundColor: '#F5F3EF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 11, minHeight: 44, justifyContent: 'center' }}>
            <AppText style={{ fontSize: 15, color: detail.weight ? '#1A1A1A' : '#B0A99F' }}>{valueToString(detail.weight) || '예: 4.2'}</AppText>
          </Pressable>
        </Field>
      )}

      {includeNote && typeId !== 'weight' && onNoteChange && (
        <Field label="메모 (선택)">
          <MemoInput value={note} onChange={onNoteChange} inBottomSheet={inBottomSheet} onFocus={onMemoFocus} />
        </Field>
      )}

      <NumericInputModal
        visible={numpadConfig !== null}
        label={numpadConfig?.label}
        unit={numpadConfig?.unit}
        initialValue={numpadConfig?.value ?? ''}
        allowDecimal={numpadConfig?.allowDecimal}
        onConfirm={(v) => {
          numpadConfig?.onConfirm(v);
          setNumpadConfig(null);
        }}
        onCancel={() => setNumpadConfig(null)}
      />

      {vetDatePickerOpen ? (
        <BottomSheet
          ref={vetDateSheetRef}
          index={0}
          enableDynamicSizing
          enablePanDownToClose
          onClose={() => setVetDatePickerOpen(false)}
          backdropComponent={(props) => (
            <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />
          )}
          backgroundStyle={{ backgroundColor: '#FFFFFF', borderRadius: 24 }}
          handleIndicatorStyle={{ backgroundColor: '#D4CFC8' }}
        >
          <BottomSheetView style={{ paddingHorizontal: 20, paddingBottom: 40 }}>
            <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginBottom: 16, marginTop: 8 }}>날짜 선택</AppText>
            <View style={{ borderWidth: 1, borderColor: '#E8E4DE', borderRadius: 12, overflow: 'hidden', marginBottom: 20 }}>
              <DrumRollDatePicker value={pendingVetNextVisitDate} onChange={setPendingVetNextVisitDate} />
            </View>
            <View style={{ flexDirection: 'row', gap: 8 }}>
              <Pressable
                onPress={() => {
                  setPendingVetNextVisitDate(detail.vetNextVisitDate || todayString());
                  setVetDatePickerOpen(false);
                  vetDateSheetRef.current?.close();
                }}
                style={{ flex: 1, paddingVertical: 13, borderRadius: 14, backgroundColor: '#F5F3EF', alignItems: 'center' }}
              >
                <AppText style={{ fontSize: 14, color: '#6B6B6B' }}>취소</AppText>
              </Pressable>
              <Pressable
                onPress={() => {
                  patch({ vetNextVisitDate: pendingVetNextVisitDate });
                  setVetDatePickerOpen(false);
                  vetDateSheetRef.current?.close();
                }}
                style={{ flex: 2, paddingVertical: 13, borderRadius: 14, backgroundColor: colors.primary, alignItems: 'center' }}
              >
                <AppText bold style={{ fontSize: 14, color: '#FFFFFF' }}>확인</AppText>
              </Pressable>
            </View>
          </BottomSheetView>
        </BottomSheet>
      ) : null}
    </>
  );
}
