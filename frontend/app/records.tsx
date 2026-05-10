import BottomSheet, { BottomSheetBackdrop, BottomSheetScrollView, BottomSheetView } from '@gorhom/bottom-sheet';
import { Alert, Image, InteractionManager, Pressable, ScrollView, TextInput, View } from 'react-native';
import { router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useRef, useState } from 'react';
import { format, parseISO } from 'date-fns';
import { ko } from 'date-fns/locale';
import Toast from 'react-native-toast-message';
import { usePets } from '@/src/lib/pet-context';
import { getActiveDates } from '@/src/services/records';
import { QUICK_TYPES } from '@/src/lib/record-types';
import { todayString } from '@/src/lib/utils';
import { getRecordSummary, formatTime, sortByTime } from '@/src/lib/record-utils';
import RecordCalendar from '@/src/components/records/RecordCalendar';
import AppText from '@/src/components/shared/AppText';
import { showSuccessToast } from '@/src/components/shared/AppToast';
import NumericInputModal from '@/src/components/shared/NumericInputModal';
import DrumRollDatePicker from '@/src/components/shared/DrumRollDatePicker';
import DrumRollTimePicker, { formatTime12h } from '@/src/components/shared/DrumRollTimePicker';
import { colors } from '@/src/lib/colors';
import { ActivityRecord } from '@/src/types';

type Draft = {
  time: string;
  note: string;
  foodType?: ActivityRecord['foodType'];
  feedingMethod?: ActivityRecord['feedingMethod'];
  servedAmount: string;
  consumeMode: 'percent' | 'direct';
  consumedPercent: string;
  consumedAmount: string;
  brand: string;
  product: string;
  amount: string;
  medicineName: string;
  ingredients: string;
  dosage: string;
  poopShape?: ActivityRecord['poopShape'];
  poopColor?: ActivityRecord['poopColor'];
  poopAmount?: ActivityRecord['poopAmount'];
  poopSmell?: ActivityRecord['poopSmell'];
  distance: string;
  duration: string;
  weight: string;
  vetClinicName: string;
  vetVisitReason?: ActivityRecord['vetVisitReason'];
  vetDiagnosis: string;
  vetTreatment: string;
  vetCost: string;
  vetNextVisitDate: string;
};

type SheetMode = 'detail' | 'edit';
type PendingRecordAction =
  | { type: 'update'; recordId: string; updates: Partial<Omit<ActivityRecord, 'id'>> }
  | { type: 'delete'; recordId: string }
  | null;

const FOOD_TYPE_LABEL: Record<string, string> = {
  dry: '🥣 건식',
  wet: '🥫 습식',
  treat: '🦴 간식',
  prescription: '💊 처방식',
  raw: '🥩 생식',
  freezeDried: '❄️ 동결건조',
  other: '· 기타',
};

const FEEDING_METHOD_LABEL: Record<string, string> = {
  hand: '배식',
  free: '자율급식',
  autoFeeder: '자동급식기',
  other: '기타',
};

const POOP_SHAPE_LABEL: Record<string, string> = {
  normal: '💩 정상',
  soft: '🫠 묽음',
  hard: '🪨 딱딱함',
  liquid: '💦 액체',
  thin: '🎀 가는변',
  pellet: '🫘 과립형',
};

const POOP_COLOR_LABEL: Record<string, string> = {
  yellow: '노랑',
  lightBrown: '연한 갈색',
  brown: '갈색',
  darkBrown: '진한 갈색',
  black: '검정',
  red: '빨강',
  green: '초록',
  other: '기타',
};

const POOP_AMOUNT_LABEL: Record<string, string> = {
  small: '소량',
  normal: '보통',
  large: '다량',
};

const POOP_SMELL_LABEL: Record<string, string> = {
  none: '😊 없음',
  mild: '🙂 약함',
  strong: '😣 강함',
  veryStrong: '🤢 매우 강함',
};

const VET_REASON_LABEL: Record<string, string> = {
  checkup: '정기검진',
  vaccination: '예방접종',
  treatment: '치료',
  surgery: '수술',
  other: '기타',
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

function makeDraft(record: ActivityRecord): Draft {
  return {
    time: record.time ?? '',
    note: record.note ?? '',
    foodType: record.foodType,
    feedingMethod: record.feedingMethod,
    servedAmount: record.servedAmount != null ? String(record.servedAmount) : '',
    consumeMode: record.consumedPercent != null ? 'percent' : 'direct',
    consumedPercent: record.consumedPercent != null ? String(record.consumedPercent) : '',
    consumedAmount: record.consumedAmount != null ? String(record.consumedAmount) : '',
    brand: record.brand ?? '',
    product: record.product ?? '',
    amount: record.amount != null ? String(record.amount) : '',
    medicineName: record.medicineName ?? '',
    ingredients: record.ingredients ?? '',
    dosage: record.dosage ?? '',
    poopShape: record.poopShape,
    poopColor: record.poopColor,
    poopAmount: record.poopAmount,
    poopSmell: record.poopSmell,
    distance: record.distance != null ? String(record.distance) : '',
    duration: record.duration != null ? String(record.duration) : '',
    weight: record.weight != null ? String(record.weight) : '',
    vetClinicName: record.vetClinicName ?? '',
    vetVisitReason: record.vetVisitReason,
    vetDiagnosis: record.vetDiagnosis ?? '',
    vetTreatment: record.vetTreatment ?? '',
    vetCost: record.vetCost != null ? String(record.vetCost) : '',
    vetNextVisitDate: record.vetNextVisitDate ?? '',
  };
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <View style={{ marginBottom: 14 }}>
      <AppText bold style={{ fontSize: 13, color: '#3A3A3A', marginBottom: 8 }}>{label}</AppText>
      {children}
    </View>
  );
}

function ReadOnlyField({ label, value }: { label: string; value?: string | number | null }) {
  if (value === undefined || value === null || value === '') return null;
  return (
    <Field label={label}>
      <View style={{ backgroundColor: '#F5F3EF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12, minHeight: 44, justifyContent: 'center' }}>
        <AppText style={{ fontSize: 15, color: '#1A1A1A' }}>{value}</AppText>
      </View>
    </Field>
  );
}

function EditInput({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}) {
  return (
    <Field label={label}>
      <TextInput
        value={value}
        onChangeText={onChange}
        placeholder={placeholder}
        placeholderTextColor="#B0A99F"
        style={{
          backgroundColor: '#F5F3EF',
          borderRadius: 12,
          paddingHorizontal: 16,
          paddingVertical: 12,
          fontSize: 15,
          color: '#1A1A1A',
        }}
      />
    </Field>
  );
}

function ValueButton({ value, placeholder, onPress }: { value: string; placeholder: string; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={{ backgroundColor: '#F5F3EF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12, minHeight: 44, justifyContent: 'center' }}
    >
      <AppText style={{ fontSize: 15, color: value ? '#1A1A1A' : '#B0A99F' }}>{value || placeholder}</AppText>
    </Pressable>
  );
}

function ToggleGroup<T extends string>({
  options,
  value,
  onChange,
}: {
  options: { value: T; label: string; emoji?: string }[];
  value: T | undefined;
  onChange: (value: T | undefined) => void;
}) {
  return (
    <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap' }}>
      {options.map((option) => {
        const selected = value === option.value;
        return (
          <Pressable
            key={option.value}
            onPress={() => onChange(selected ? undefined : option.value)}
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
            {option.emoji ? <AppText style={{ fontSize: 14 }}>{option.emoji}</AppText> : null}
            <AppText style={{ fontSize: 13, color: selected ? '#FFFFFF' : '#3A3A3A' }}>{option.label}</AppText>
          </Pressable>
        );
      })}
    </View>
  );
}

function ColorToggleGroup({
  value,
  onChange,
}: {
  value: ActivityRecord['poopColor'];
  onChange: (value: ActivityRecord['poopColor']) => void;
}) {
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
      {POOP_COLORS.map((color) => {
        const selected = value === color.value;
        return (
          <Pressable
            key={color.value}
            onPress={() => onChange(selected ? undefined : color.value)}
            style={{
              alignItems: 'center',
              gap: 4,
              borderWidth: 2,
              borderColor: selected ? colors.primary : 'transparent',
              borderRadius: 12,
              padding: 6,
            }}
          >
            <View style={{ width: 32, height: 32, borderRadius: 16, backgroundColor: color.hex, borderWidth: 1, borderColor: '#E8E4DE' }} />
            <AppText style={{ fontSize: 10, color: selected ? colors.primary : '#6B6B6B' }}>{color.label}</AppText>
          </Pressable>
        );
      })}
    </View>
  );
}

function RecordFields({
  record,
  draft,
  setDraft,
  readOnly,
  openNum,
  openTimePicker,
  openDatePicker,
}: {
  record: ActivityRecord;
  draft?: Draft;
  setDraft?: React.Dispatch<React.SetStateAction<Draft | null>>;
  readOnly: boolean;
  openNum?: (label: string, value: string, unit: string | undefined, onConfirm: (value: string) => void, allowDecimal?: boolean) => void;
  openTimePicker?: () => void;
  openDatePicker?: () => void;
}) {
  const set = (key: keyof Draft) => (value: string) => {
    setDraft?.((prev) => prev ? ({ ...prev, [key]: value }) : prev);
  };
  const setOption = <K extends keyof Draft>(key: K) => (value: Draft[K]) => {
    setDraft?.((prev) => prev ? ({ ...prev, [key]: value }) : prev);
  };

  if (readOnly) {
    return (
      <>
        <ReadOnlyField label="시간 (선택)" value={record.time ? formatTime(record.time) : undefined} />
        {record.typeId === 'meal' && (
          <>
            <ReadOnlyField label="사료 종류" value={record.foodType ? FOOD_TYPE_LABEL[record.foodType] : undefined} />
            <ReadOnlyField label="급식 방법" value={record.feedingMethod ? FEEDING_METHOD_LABEL[record.feedingMethod] : undefined} />
            <ReadOnlyField label="급여량 (g)" value={record.servedAmount != null ? `${record.servedAmount}g` : undefined} />
            <ReadOnlyField label="섭취량" value={record.consumedPercent != null ? `${record.consumedPercent}%` : record.consumedAmount != null ? `${record.consumedAmount}g` : undefined} />
            <ReadOnlyField label="브랜드명" value={record.brand} />
            <ReadOnlyField label="제품명" value={record.product} />
          </>
        )}
        {record.typeId === 'water' && <ReadOnlyField label="음수량 (ml)" value={record.amount != null ? `${record.amount}ml` : undefined} />}
        {record.typeId === 'medicine' && (
          <>
            <ReadOnlyField label="약 이름" value={record.medicineName} />
            <ReadOnlyField label="성분" value={record.ingredients} />
            <ReadOnlyField label="용량" value={record.dosage} />
          </>
        )}
        {record.typeId === 'poop' && (
          <>
            <ReadOnlyField label="모양" value={record.poopShape ? POOP_SHAPE_LABEL[record.poopShape] : undefined} />
            <ReadOnlyField label="색상" value={record.poopColor ? POOP_COLOR_LABEL[record.poopColor] : undefined} />
            <ReadOnlyField label="양" value={record.poopAmount ? POOP_AMOUNT_LABEL[record.poopAmount] : undefined} />
            <ReadOnlyField label="냄새" value={record.poopSmell ? POOP_SMELL_LABEL[record.poopSmell] : undefined} />
            {record.poopPhotos && record.poopPhotos.length > 0 ? (
              <Field label={`사진 (${record.poopPhotos.length})`}>
                <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap' }}>
                  {record.poopPhotos.map((uri, index) => (
                    <Image key={`${uri}-${index}`} source={{ uri }} style={{ width: 80, height: 80, borderRadius: 10 }} />
                  ))}
                </View>
              </Field>
            ) : null}
          </>
        )}
        {record.typeId === 'walk' && (
          <>
            <ReadOnlyField label="거리 (m)" value={record.distance != null ? `${record.distance}m` : undefined} />
            <ReadOnlyField label="소요시간 (분)" value={record.duration != null ? `${record.duration}분` : undefined} />
          </>
        )}
        {(record.typeId === 'sleep' || record.typeId === 'play') && <ReadOnlyField label="시간 (분)" value={record.duration != null ? `${record.duration}분` : undefined} />}
        {record.typeId === 'weight' && <ReadOnlyField label="체중 (kg)" value={record.weight != null ? `${record.weight}kg` : undefined} />}
        {record.typeId === 'vet' && (
          <>
            <ReadOnlyField label="병원명" value={record.vetClinicName} />
            <ReadOnlyField label="방문 목적" value={record.vetVisitReason ? VET_REASON_LABEL[record.vetVisitReason] : undefined} />
            <ReadOnlyField label="진단 내용" value={record.vetDiagnosis} />
            <ReadOnlyField label="처방/치료" value={record.vetTreatment} />
            <ReadOnlyField label="비용 (원)" value={record.vetCost != null ? `${record.vetCost}원` : undefined} />
            <ReadOnlyField label="다음 방문 예정일 (선택)" value={record.vetNextVisitDate} />
          </>
        )}
        {record.typeId !== 'weight' && <ReadOnlyField label="메모 (선택)" value={record.note} />}
      </>
    );
  }

  if (!draft || !openNum || !openTimePicker || !openDatePicker) return null;

  return (
    <>
      <Field label="시간 (선택)">
        <ValueButton value={draft.time ? formatTime12h(draft.time) : ''} placeholder="예: 09:00" onPress={openTimePicker} />
      </Field>
      {record.typeId === 'meal' && (
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
              value={draft.foodType}
              onChange={setOption('foodType')}
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
              value={draft.feedingMethod}
              onChange={setOption('feedingMethod')}
            />
          </Field>
          <Field label="급여량 (g)">
            <ValueButton value={draft.servedAmount} placeholder="예: 100" onPress={() => openNum('급여량', draft.servedAmount, 'g', set('servedAmount'))} />
          </Field>
          <Field label="섭취량">
            <View style={{ flexDirection: 'row', gap: 8, marginBottom: 8 }}>
              {(['percent', 'direct'] as const).map((mode) => (
                <Pressable
                  key={mode}
                  onPress={() => setOption('consumeMode')(mode)}
                  style={{
                    paddingHorizontal: 14,
                    paddingVertical: 7,
                    borderRadius: 20,
                    backgroundColor: draft.consumeMode === mode ? colors.primary : '#F5F3EF',
                    borderWidth: 1,
                    borderColor: draft.consumeMode === mode ? colors.primary : '#E8E4DE',
                  }}
                >
                  <AppText style={{ fontSize: 13, color: draft.consumeMode === mode ? '#FFFFFF' : '#3A3A3A' }}>
                    {mode === 'percent' ? '% 입력' : '직접 입력 (g)'}
                  </AppText>
                </Pressable>
              ))}
            </View>
            <ValueButton
              value={draft.consumeMode === 'percent' ? draft.consumedPercent : draft.consumedAmount}
              placeholder={draft.consumeMode === 'percent' ? '예: 80 (%)' : '예: 80 (g)'}
              onPress={() => {
                const isPercent = draft.consumeMode === 'percent';
                openNum('섭취량', isPercent ? draft.consumedPercent : draft.consumedAmount, isPercent ? '%' : 'g', isPercent ? set('consumedPercent') : set('consumedAmount'));
              }}
            />
          </Field>
          <EditInput label="브랜드명" value={draft.brand} onChange={set('brand')} placeholder="예: 로얄캐닌" />
          <EditInput label="제품명" value={draft.product} onChange={set('product')} placeholder="예: 미니 인도어" />
        </>
      )}
      {record.typeId === 'water' && (
        <Field label="음수량 (ml)">
          <ValueButton value={draft.amount} placeholder="예: 150" onPress={() => openNum('음수량', draft.amount, 'ml', set('amount'))} />
        </Field>
      )}
      {record.typeId === 'medicine' && (
        <>
          <EditInput label="약 이름" value={draft.medicineName} onChange={set('medicineName')} placeholder="예: 항생제" />
          <EditInput label="성분" value={draft.ingredients} onChange={set('ingredients')} placeholder="예: 아목시실린" />
          <EditInput label="용량" value={draft.dosage} onChange={set('dosage')} placeholder="예: 1정" />
        </>
      )}
      {record.typeId === 'poop' && (
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
              value={draft.poopShape}
              onChange={setOption('poopShape')}
            />
          </Field>
          <Field label="색상">
            <ColorToggleGroup value={draft.poopColor} onChange={setOption('poopColor')} />
          </Field>
          <Field label="양">
            <ToggleGroup
              options={[
                { value: 'small' as const, label: '소량' },
                { value: 'normal' as const, label: '보통' },
                { value: 'large' as const, label: '다량' },
              ]}
              value={draft.poopAmount}
              onChange={setOption('poopAmount')}
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
              value={draft.poopSmell}
              onChange={setOption('poopSmell')}
            />
          </Field>
        </>
      )}
      {record.typeId === 'walk' && (
        <>
          <Field label="거리 (m)">
            <ValueButton value={draft.distance} placeholder="예: 500" onPress={() => openNum('거리', draft.distance, 'm', set('distance'))} />
          </Field>
          <Field label="소요시간 (분)">
            <ValueButton value={draft.duration} placeholder="예: 30" onPress={() => openNum('소요시간', draft.duration, '분', set('duration'))} />
          </Field>
        </>
      )}
      {(record.typeId === 'sleep' || record.typeId === 'play') && (
        <Field label="시간 (분)">
          <ValueButton value={draft.duration} placeholder="예: 60" onPress={() => openNum('시간', draft.duration, '분', set('duration'))} />
        </Field>
      )}
      {record.typeId === 'weight' && (
        <Field label="체중 (kg)">
          <ValueButton value={draft.weight} placeholder="예: 4.2" onPress={() => openNum('체중', draft.weight, 'kg', set('weight'))} />
        </Field>
      )}
      {record.typeId === 'vet' && (
        <>
          <EditInput label="병원명" value={draft.vetClinicName} onChange={set('vetClinicName')} placeholder="예: 행복동물병원" />
          <Field label="방문 목적">
            <ToggleGroup
              options={[
                { value: 'checkup' as const, label: '정기검진' },
                { value: 'vaccination' as const, label: '예방접종' },
                { value: 'treatment' as const, label: '치료' },
                { value: 'surgery' as const, label: '수술' },
                { value: 'other' as const, label: '기타' },
              ]}
              value={draft.vetVisitReason}
              onChange={setOption('vetVisitReason')}
            />
          </Field>
          <EditInput label="진단 내용" value={draft.vetDiagnosis} onChange={set('vetDiagnosis')} placeholder="예: 슬개골 탈구 2단계" />
          <EditInput label="처방/치료" value={draft.vetTreatment} onChange={set('vetTreatment')} placeholder="예: 약 처방, 안정 권고" />
          <Field label="비용 (원)">
            <ValueButton value={draft.vetCost ? `${draft.vetCost}원` : ''} placeholder="예: 50000" onPress={() => openNum('비용', draft.vetCost, '원', set('vetCost'), false)} />
          </Field>
          <Field label="다음 방문 예정일 (선택)">
            <ValueButton value={draft.vetNextVisitDate} placeholder="예: 2026-06-01" onPress={openDatePicker} />
          </Field>
        </>
      )}
      {record.typeId !== 'weight' && <EditInput label="메모 (선택)" value={draft.note} onChange={set('note')} placeholder="간단한 메모" />}
    </>
  );
}

export default function RecordsScreen() {
  const insets = useSafeAreaInsets();
  const recordSheetRef = useRef<BottomSheet>(null);
  const timeSheetRef = useRef<BottomSheet>(null);
  const dateSheetRef = useRef<BottomSheet>(null);
  const pendingRecordActionRef = useRef<PendingRecordAction>(null);
  const isRunningRecordActionRef = useRef(false);
  const { pets, activePetId, records, openModal, updateRecord, deleteRecord } = usePets();
  const pet = pets.find((p) => p.id === activePetId);
  const [selectedDate, setSelectedDate] = useState(todayString());
  const [sheetMode, setSheetMode] = useState<SheetMode | null>(null);
  const [sheetRecord, setSheetRecord] = useState<ActivityRecord | null>(null);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [isSavingEdit, setIsSavingEdit] = useState(false);
  const [isDeletingRecord, setIsDeletingRecord] = useState(false);
  const [, setPendingRecordAction] = useState<PendingRecordAction>(null);
  const [pendingTime, setPendingTime] = useState('09:00');
  const [pendingVetDate, setPendingVetDate] = useState(todayString());
  const [numpadConfig, setNumpadConfig] = useState<{
    label: string;
    unit?: string;
    value: string;
    onConfirm: (value: string) => void;
    allowDecimal?: boolean;
  } | null>(null);

  if (!pet) return null;

  const markedDates = getActiveDates(records, pet.id);
  const dayRecords = sortByTime(records.filter((record) => record.petId === pet.id && record.date === selectedDate));

  function openNum(label: string, value: string, unit: string | undefined, onConfirm: (value: string) => void, allowDecimal = true) {
    setNumpadConfig({ label, unit, value, onConfirm, allowDecimal });
  }

  function updatePendingRecordAction(action: PendingRecordAction) {
    pendingRecordActionRef.current = action;
    setPendingRecordAction(action);
  }

  function runPendingRecordAction() {
    const action = pendingRecordActionRef.current;
    if (!action || isRunningRecordActionRef.current) return;
    isRunningRecordActionRef.current = true;

    InteractionManager.runAfterInteractions(async () => {
      try {
        if (action.type === 'update') {
          await updateRecord(action.recordId, action.updates);
          showSuccessToast('기록 수정 완료');
        } else {
          await deleteRecord(action.recordId);
          showSuccessToast('기록 삭제 완료');
        }
      } catch (error) {
        Toast.show({ type: 'error', text1: error instanceof Error ? error.message : action.type === 'update' ? 'Update failed' : 'Delete failed' });
      } finally {
        isRunningRecordActionRef.current = false;
        updatePendingRecordAction(null);
        setIsSavingEdit(false);
        setIsDeletingRecord(false);
      }
    });
  }

  function handleRecordSheetClose() {
    if (pendingRecordActionRef.current) runPendingRecordAction();
    setSheetMode(null);
    setSheetRecord(null);
    setDraft(null);
    if (!pendingRecordActionRef.current) {
      setIsSavingEdit(false);
      setIsDeletingRecord(false);
    }
  }

  function openRecordDetail(record: ActivityRecord) {
    setSheetMode('detail');
    setSheetRecord(record);
    setDraft(null);
    requestAnimationFrame(() => recordSheetRef.current?.expand());
  }

  function openRecordEdit(record: ActivityRecord) {
    if (isSavingEdit || isDeletingRecord) return;
    setSheetMode('edit');
    setSheetRecord(record);
    setDraft(makeDraft(record));
    setPendingTime(record.time ?? '09:00');
    setPendingVetDate(record.vetNextVisitDate ?? todayString());
    requestAnimationFrame(() => recordSheetRef.current?.expand());
  }

  function confirmDelete(id: string) {
    if (isSavingEdit || isDeletingRecord) return;
    Alert.alert('기록 삭제', '이 기록을 삭제할까요?', [
      { text: '취소', style: 'cancel' },
      {
        text: '삭제',
        style: 'destructive',
        onPress: () => {
          setIsDeletingRecord(true);
          updatePendingRecordAction({ type: 'delete', recordId: id });
          timeSheetRef.current?.close();
          dateSheetRef.current?.close();
          recordSheetRef.current?.close();
        },
      },
    ]);
  }

  async function saveEdit() {
    if (!sheetRecord || !draft || sheetMode !== 'edit' || isSavingEdit || isDeletingRecord) return;
    const updates: Partial<Omit<ActivityRecord, 'id'>> = {
      time: draft.time.trim() || undefined,
      note: draft.note.trim() || undefined,
    };

    if (sheetRecord.typeId === 'meal') {
      updates.foodType = draft.foodType;
      updates.feedingMethod = draft.feedingMethod;
      updates.servedAmount = draft.servedAmount ? parseFloat(draft.servedAmount) : undefined;
      updates.consumedPercent = draft.consumeMode === 'percent' && draft.consumedPercent ? parseFloat(draft.consumedPercent) : undefined;
      updates.consumedAmount = draft.consumeMode === 'direct' && draft.consumedAmount ? parseFloat(draft.consumedAmount) : undefined;
      updates.brand = draft.brand.trim() || undefined;
      updates.product = draft.product.trim() || undefined;
    }
    if (sheetRecord.typeId === 'water') updates.amount = draft.amount ? parseFloat(draft.amount) : undefined;
    if (sheetRecord.typeId === 'medicine') {
      updates.medicineName = draft.medicineName.trim() || undefined;
      updates.ingredients = draft.ingredients.trim() || undefined;
      updates.dosage = draft.dosage.trim() || undefined;
    }
    if (sheetRecord.typeId === 'poop') {
      updates.poopShape = draft.poopShape;
      updates.poopColor = draft.poopColor;
      updates.poopAmount = draft.poopAmount;
      updates.poopSmell = draft.poopSmell;
    }
    if (sheetRecord.typeId === 'walk') {
      updates.distance = draft.distance ? parseFloat(draft.distance) : undefined;
      updates.duration = draft.duration ? parseFloat(draft.duration) : undefined;
    }
    if (sheetRecord.typeId === 'sleep' || sheetRecord.typeId === 'play') updates.duration = draft.duration ? parseFloat(draft.duration) : undefined;
    if (sheetRecord.typeId === 'weight') updates.weight = draft.weight ? parseFloat(draft.weight) : undefined;
    if (sheetRecord.typeId === 'vet') {
      updates.vetClinicName = draft.vetClinicName.trim() || undefined;
      updates.vetVisitReason = draft.vetVisitReason;
      updates.vetDiagnosis = draft.vetDiagnosis.trim() || undefined;
      updates.vetTreatment = draft.vetTreatment.trim() || undefined;
      updates.vetCost = draft.vetCost ? parseFloat(draft.vetCost) : undefined;
      updates.vetNextVisitDate = draft.vetNextVisitDate.trim() || undefined;
    }

    setIsSavingEdit(true);
    updatePendingRecordAction({ type: 'update', recordId: sheetRecord.id, updates });
    timeSheetRef.current?.close();
    dateSheetRef.current?.close();
    recordSheetRef.current?.close();
  }

  const parsedDate = parseISO(selectedDate);
  const currentYear = new Date().getFullYear();
  const dateTitle = parsedDate.getFullYear() !== currentYear
    ? format(parsedDate, 'yyyy년 M월 d일 EEEE', { locale: ko })
    : format(parsedDate, 'M월 d일 EEEE', { locale: ko });
  const selectedMonth = selectedDate.slice(0, 7);
  const monthRecordCount = records.filter((record) => record.petId === pet.id && record.date.startsWith(selectedMonth)).length;
  const sheetType = sheetRecord ? QUICK_TYPES.find((type) => type.id === sheetRecord.typeId) : null;

  return (
    <>
      <View style={{ flex: 1, backgroundColor: colors.background, paddingTop: insets.top }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 12 }}>
          <Pressable onPress={() => router.back()} style={{ marginRight: 8 }}>
            <Ionicons name="chevron-back" size={26} color="#1A1A1A" />
          </Pressable>
          <AppText bold style={{ fontSize: 17, color: '#1A1A1A', flex: 1 }}>{pet.name}의 기록</AppText>
          <Pressable
            onPress={() => openModal(null, selectedDate)}
            style={{ backgroundColor: pet.accentColor, borderRadius: 20, paddingHorizontal: 14, paddingVertical: 7 }}
          >
            <AppText bold style={{ color: '#FFFFFF', fontSize: 13 }}>+ 추가</AppText>
          </Pressable>
        </View>

        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: 40 }}>
          {monthRecordCount > 0 && (
            <View style={{ paddingHorizontal: 20, paddingBottom: 8, alignItems: 'flex-end' }}>
              <AppText style={{ fontSize: 12, color: '#B0A99F' }}>
                {parseInt(selectedMonth.slice(5), 10)}월 기록 {monthRecordCount}건
              </AppText>
            </View>
          )}

          <RecordCalendar
            markedDates={markedDates}
            selectedDate={selectedDate}
            onSelect={setSelectedDate}
            accentColor={pet.accentColor}
            onTodayPress={() => setSelectedDate(todayString())}
          />

          <View style={{ marginHorizontal: 20, marginTop: 16, backgroundColor: colors.surface, borderRadius: 18, borderWidth: 1, borderColor: colors.border, overflow: 'hidden', minHeight: 112 }}>
            <View style={{ paddingHorizontal: 16, paddingTop: 14, paddingBottom: 8, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
              <AppText bold style={{ fontSize: 14, color: '#1A1A1A' }}>{dateTitle}</AppText>
              {dayRecords.length > 0 && <AppText style={{ fontSize: 12, color: '#B0A99F' }}>{dayRecords.length}건</AppText>}
            </View>

            {dayRecords.length === 0 ? (
              <View style={{ paddingHorizontal: 16, paddingBottom: 24, paddingTop: 8, alignItems: 'center', minHeight: 80 }}>
                <AppText style={{ fontSize: 32, marginBottom: 8 }}>📝</AppText>
                <AppText style={{ fontSize: 14, color: colors.muted }}>이 날의 기록이 없어요</AppText>
              </View>
            ) : (
              dayRecords.map((record, index) => {
                const typeInfo = QUICK_TYPES.find((type) => type.id === record.typeId);
                const summary = getRecordSummary(record);
                return (
                  <View key={record.id}>
                    {index > 0 && <View style={{ height: 1, backgroundColor: colors.border, marginHorizontal: 16 }} />}
                    <Pressable
                      onPress={() => openRecordDetail(record)}
                      style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, gap: 12 }}
                    >
                      <View style={{ width: 40, height: 40, borderRadius: 12, backgroundColor: typeInfo?.bg ?? colors.surfaceSoft, borderWidth: 1, borderColor: colors.border, alignItems: 'center', justifyContent: 'center' }}>
                        <AppText style={{ fontSize: 20 }}>{typeInfo?.emoji ?? '📌'}</AppText>
                      </View>
                      <View style={{ flex: 1 }}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                          <AppText bold style={{ fontSize: 14, color: '#1A1A1A' }}>{typeInfo?.label ?? record.typeId}</AppText>
                          {record.time && <AppText style={{ fontSize: 12, color: '#B0A99F' }}>{formatTime(record.time)}</AppText>}
                        </View>
                        {summary ? <AppText style={{ fontSize: 12, color: '#6B6B6B', marginTop: 2 }} numberOfLines={1}>{summary}</AppText> : null}
                      </View>
                      <View style={{ width: 28, alignItems: 'flex-end' }}>
                        <Pressable
                          onPress={(event) => {
                            event.stopPropagation();
                            openRecordEdit(record);
                          }}
                          hitSlop={8}
                        >
                          <Ionicons name="create-outline" size={21} color="#B0A99F" />
                        </Pressable>
                      </View>
                    </Pressable>
                  </View>
                );
              })
            )}
          </View>
        </ScrollView>
      </View>

      <BottomSheet
        ref={recordSheetRef}
        index={-1}
        snapPoints={[sheetMode === 'edit' ? '90%' : '85%']}
        enablePanDownToClose
        onClose={handleRecordSheetClose}
        backdropComponent={(props) => <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />}
        backgroundStyle={{ backgroundColor: colors.surface, borderRadius: 24 }}
        handleIndicatorStyle={{ backgroundColor: '#D4CFC8' }}
        keyboardBehavior="interactive"
        keyboardBlurBehavior="restore"
      >
        <BottomSheetScrollView keyboardDismissMode="on-drag" keyboardShouldPersistTaps="handled" contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 40 }}>
          {sheetRecord && sheetMode === 'detail' ? (
            <>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, backgroundColor: '#FFFFFF', borderRadius: 16, paddingVertical: 8, marginBottom: 12 }}>
                <View style={{ width: 44, height: 44, borderRadius: 12, backgroundColor: sheetType?.bg ?? '#F5F3EF', alignItems: 'center', justifyContent: 'center' }}>
                  <AppText style={{ fontSize: 22 }}>{sheetType?.emoji ?? '📌'}</AppText>
                </View>
                <View style={{ flex: 1 }}>
                  <AppText bold style={{ fontSize: 15, color: '#1A1A1A' }}>{sheetType?.label ?? sheetRecord.typeId}</AppText>
                  <AppText style={{ fontSize: 12, color: '#B0A99F' }}>{format(parseISO(sheetRecord.date), 'yyyy년 M월 d일 EEEE', { locale: ko })}</AppText>
                </View>
                <Pressable onPress={() => openRecordEdit(sheetRecord)} hitSlop={8} style={{ padding: 4 }}>
                  <Ionicons name="create-outline" size={22} color="#B0A99F" />
                </Pressable>
              </View>
              <RecordFields record={sheetRecord} readOnly />
            </>
          ) : null}
          {sheetRecord && sheetMode === 'edit' && draft ? (
            <>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginVertical: 12 }}>
                <View style={{ width: 44, height: 44, borderRadius: 12, backgroundColor: sheetType?.bg ?? '#F5F3EF', alignItems: 'center', justifyContent: 'center' }}>
                  <AppText style={{ fontSize: 22 }}>{sheetType?.emoji ?? '📌'}</AppText>
                </View>
                <View>
                  <AppText bold style={{ fontSize: 17, color: '#1A1A1A' }}>기록 수정</AppText>
                  <AppText style={{ fontSize: 12, color: '#B0A99F' }}>{sheetType?.label ?? sheetRecord.typeId}</AppText>
                </View>
              </View>
              <RecordFields
                record={sheetRecord}
                draft={draft}
                setDraft={setDraft}
                readOnly={false}
                openNum={openNum}
                openTimePicker={() => {
                  setPendingTime(draft.time || '09:00');
                  timeSheetRef.current?.expand();
                }}
                openDatePicker={() => {
                  setPendingVetDate(draft.vetNextVisitDate || todayString());
                  dateSheetRef.current?.expand();
                }}
              />
              <Pressable
                disabled={isSavingEdit || isDeletingRecord}
                onPress={saveEdit}
                style={{ backgroundColor: colors.primary, borderRadius: 16, paddingVertical: 16, alignItems: 'center', marginTop: 4, opacity: isSavingEdit || isDeletingRecord ? 0.6 : 1 }}
              >
                <AppText bold style={{ color: '#FFFFFF', fontSize: 15 }}>{isSavingEdit ? '저장 중...' : '수정 완료'}</AppText>
              </Pressable>
              <Pressable
                disabled={isSavingEdit || isDeletingRecord}
                onPress={() => confirmDelete(sheetRecord.id)}
                style={{ borderRadius: 16, paddingVertical: 14, alignItems: 'center', marginTop: 10, borderWidth: 1, borderColor: '#EF4444', opacity: isSavingEdit || isDeletingRecord ? 0.6 : 1 }}
              >
                <AppText bold style={{ color: '#EF4444', fontSize: 15 }}>{isDeletingRecord ? '삭제 중...' : '기록 삭제'}</AppText>
              </Pressable>
            </>
          ) : null}
        </BottomSheetScrollView>
      </BottomSheet>

      <BottomSheet
        ref={timeSheetRef}
        index={-1}
        enableDynamicSizing
        enablePanDownToClose
        backdropComponent={(props) => <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />}
        backgroundStyle={{ backgroundColor: '#FFFFFF', borderRadius: 24 }}
        handleIndicatorStyle={{ backgroundColor: '#D4CFC8' }}
      >
        <BottomSheetView style={{ paddingHorizontal: 20, paddingBottom: 40 }}>
          <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginBottom: 16, marginTop: 8 }}>시간 선택</AppText>
          <View style={{ borderWidth: 1, borderColor: '#E8E4DE', borderRadius: 12, overflow: 'hidden', marginBottom: 20 }}>
            <DrumRollTimePicker value={pendingTime} onChange={setPendingTime} />
          </View>
          <View style={{ flexDirection: 'row', gap: 8 }}>
            <Pressable onPress={() => timeSheetRef.current?.close()} style={{ flex: 1, paddingVertical: 13, borderRadius: 14, backgroundColor: '#F5F3EF', alignItems: 'center' }}>
              <AppText style={{ fontSize: 14, color: '#6B6B6B' }}>취소</AppText>
            </Pressable>
            <Pressable
              onPress={() => {
                setDraft((prev) => prev ? { ...prev, time: pendingTime } : prev);
                timeSheetRef.current?.close();
              }}
              style={{ flex: 2, paddingVertical: 13, borderRadius: 14, backgroundColor: colors.primary, alignItems: 'center' }}
            >
              <AppText bold style={{ fontSize: 14, color: '#FFFFFF' }}>확인</AppText>
            </Pressable>
          </View>
        </BottomSheetView>
      </BottomSheet>

      <BottomSheet
        ref={dateSheetRef}
        index={-1}
        enableDynamicSizing
        enablePanDownToClose
        backdropComponent={(props) => <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />}
        backgroundStyle={{ backgroundColor: '#FFFFFF', borderRadius: 24 }}
        handleIndicatorStyle={{ backgroundColor: '#D4CFC8' }}
      >
        <BottomSheetView style={{ paddingHorizontal: 20, paddingBottom: 40 }}>
          <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginBottom: 16, marginTop: 8 }}>날짜 선택</AppText>
          <View style={{ borderWidth: 1, borderColor: '#E8E4DE', borderRadius: 12, overflow: 'hidden', marginBottom: 20 }}>
            <DrumRollDatePicker value={pendingVetDate} onChange={setPendingVetDate} />
          </View>
          <View style={{ flexDirection: 'row', gap: 8 }}>
            <Pressable onPress={() => dateSheetRef.current?.close()} style={{ flex: 1, paddingVertical: 13, borderRadius: 14, backgroundColor: '#F5F3EF', alignItems: 'center' }}>
              <AppText style={{ fontSize: 14, color: '#6B6B6B' }}>취소</AppText>
            </Pressable>
            <Pressable
              onPress={() => {
                setDraft((prev) => prev ? { ...prev, vetNextVisitDate: pendingVetDate } : prev);
                dateSheetRef.current?.close();
              }}
              style={{ flex: 2, paddingVertical: 13, borderRadius: 14, backgroundColor: colors.primary, alignItems: 'center' }}
            >
              <AppText bold style={{ fontSize: 14, color: '#FFFFFF' }}>확인</AppText>
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
        onConfirm={(value) => {
          numpadConfig?.onConfirm(value);
          setNumpadConfig(null);
        }}
        onCancel={() => setNumpadConfig(null)}
      />
    </>
  );
}
