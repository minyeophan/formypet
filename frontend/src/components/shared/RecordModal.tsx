import BottomSheet, { BottomSheetBackdrop, BottomSheetScrollView, BottomSheetView } from '@gorhom/bottom-sheet';
import { Ionicons } from '@expo/vector-icons';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { InteractionManager, Platform, Pressable, View } from 'react-native';
import Toast from 'react-native-toast-message';
import { format, parseISO } from 'date-fns';
import { ko } from 'date-fns/locale';
import { usePets } from '@/src/lib/pet-context';
import { QUICK_TYPES, SUPPORTED_QUICK_TYPES } from '@/src/lib/record-types';
import { todayString } from '@/src/lib/utils';
import { colors } from '@/src/lib/colors';
import AppText from './AppText';
import { showSuccessToast } from './AppToast';
import DrumRollTimePicker, { formatTime12h } from './DrumRollTimePicker';
import RecordDetailForm, {
  RecordDetailDraft,
  createEmptyRecordDetail,
  sanitizeRecordDetail,
} from './RecordDetailForm';
import { ActivityRecord } from '@/src/types';

type ModalStep = 'type' | 'detail';
type PendingRecordCreate = Omit<ActivityRecord, 'id'> | null;

const SHEET_CONTENT_MIN_HEIGHT = 620;

export default function RecordModal() {
  const {
    modalOpen,
    closeModal,
    selectedType,
    addRecord,
    activePetId,
    modalDate,
    modalRoutineId,
    modalInitialDraft,
  } = usePets();
  const bottomSheetRef = useRef<BottomSheet>(null);
  const timeSheetRef = useRef<BottomSheet>(null);
  const snapPoints = useMemo(() => ['92%'], []);
  const isRunningCreateRef = useRef(false);
  const pendingRecordCreateRef = useRef<PendingRecordCreate>(null);
  const [sheetMounted, setSheetMounted] = useState(false);
  const [localSelectedType, setLocalSelectedType] = useState<string | null>(null);
  const [modalStep, setModalStep] = useState<ModalStep>('type');
  const [isSaving, setIsSaving] = useState(false);
  const [time, setTime] = useState('');
  const [note, setNote] = useState('');
  const [detail, setDetail] = useState<RecordDetailDraft>({});
  const [, setPendingRecordCreate] = useState<PendingRecordCreate>(null);
  const [pendingTime, setPendingTime] = useState('09:00');
  const [timePickerOpen, setTimePickerOpen] = useState(false);

  function updatePendingRecordCreate(record: PendingRecordCreate) {
    pendingRecordCreateRef.current = record;
    setPendingRecordCreate(record);
  }

  function resetAll() {
    setTime('');
    setNote('');
    setDetail({});
    updatePendingRecordCreate(null);
    setPendingTime('09:00');
    setTimePickerOpen(false);
    timeSheetRef.current?.close();
  }

  useEffect(() => {
    if (modalOpen) {
      setSheetMounted(true);
      setLocalSelectedType(selectedType);
      setModalStep(selectedType ? 'detail' : 'type');
      setTime(modalInitialDraft?.time ?? '');
      setNote(modalInitialDraft?.note ?? '');
      setDetail(selectedType ? { ...createEmptyRecordDetail(selectedType), ...modalInitialDraft } : {});
    } else if (sheetMounted) {
      bottomSheetRef.current?.close();
    }
  }, [modalOpen, selectedType, modalInitialDraft, sheetMounted]);

  const renderBackdrop = useCallback(
    (props: any) => (
      <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />
    ),
    []
  );

  function chooseType(typeId: string) {
    setLocalSelectedType(typeId);
    setDetail(createEmptyRecordDetail(typeId));
    setModalStep('detail');
  }

  function handleSheetClose() {
    resetAll();
    setLocalSelectedType(null);
    setModalStep('type');
    setSheetMounted(false);
    setIsSaving(false);
    if (modalOpen) closeModal();
  }

  function runPendingRecordCreate(recordToCreate: Omit<ActivityRecord, 'id'>) {
    if (isRunningCreateRef.current) return;
    isRunningCreateRef.current = true;

    InteractionManager.runAfterInteractions(async () => {
      try {
        await addRecord(recordToCreate);
        showSuccessToast('기록이 저장되었어요.');
      } catch (error) {
        Toast.show({ type: 'error', text1: error instanceof Error ? error.message : 'Save failed' });
      } finally {
        isRunningCreateRef.current = false;
        updatePendingRecordCreate(null);
        setIsSaving(false);
      }
    });
  }

  function handleSheetChange(index: number) {
    if (index !== -1) return;
    const recordToCreate = pendingRecordCreateRef.current;
    if (recordToCreate) {
      handleSheetClose();
      runPendingRecordCreate(recordToCreate);
      return;
    }
    handleSheetClose();
  }

  function handleSubmit() {
    const submitType = localSelectedType;
    if (!submitType || !activePetId || isSaving) return;
    updatePendingRecordCreate({
      ...sanitizeRecordDetail(submitType, detail),
      petId: activePetId,
      typeId: submitType,
      date: modalDate,
      time: time || undefined,
      note: note.trim() || undefined,
      routineId: modalRoutineId,
    });
    setIsSaving(true);
    timeSheetRef.current?.close();
    bottomSheetRef.current?.close();
  }

  const typeData = localSelectedType ? QUICK_TYPES.find((t) => t.id === localSelectedType) : null;
  const today = todayString();
  const dateLabel = modalDate !== today
    ? format(parseISO(modalDate), 'M월 d일', { locale: ko }) + ' 기록'
    : null;

  if (!sheetMounted) return null;

  return (
    <>
      <BottomSheet
        ref={bottomSheetRef}
        index={0}
        snapPoints={snapPoints}
        enablePanDownToClose
        onChange={handleSheetChange}
        backdropComponent={renderBackdrop}
        backgroundStyle={{ backgroundColor: '#FFFFFF', borderRadius: 24 }}
        handleIndicatorStyle={{ backgroundColor: '#D4CFC8' }}
        keyboardBehavior={Platform.OS === 'android' ? 'extend' : 'interactive'}
        keyboardBlurBehavior="restore"
      >
        <BottomSheetScrollView
          keyboardDismissMode="on-drag"
          keyboardShouldPersistTaps="handled"
          contentContainerStyle={{ paddingHorizontal: 24, paddingBottom: 48, minHeight: SHEET_CONTENT_MIN_HEIGHT }}
        >
          {modalStep === 'type' ? (
            <View style={{ minHeight: SHEET_CONTENT_MIN_HEIGHT }}>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4, marginTop: 4 }}>
                <AppText bold style={{ fontSize: 18, color: '#1A1A1A' }}>활동 기록</AppText>
              </View>
              {dateLabel ? (
                <AppText style={{ fontSize: 12, color: colors.primary, marginBottom: 16 }}>{dateLabel}</AppText>
              ) : (
                <View style={{ marginBottom: 16 }} />
              )}
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
                {SUPPORTED_QUICK_TYPES.map((t) => (
                  <Pressable
                    key={t.id}
                    onPress={() => chooseType(t.id)}
                    style={{
                      width: '22%',
                      aspectRatio: 1,
                      borderRadius: 16,
                      backgroundColor: t.bg,
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <AppText style={{ fontSize: 24 }}>{t.emoji}</AppText>
                    <AppText style={{ fontSize: 11, color: '#6B6B6B', marginTop: 4 }}>{t.label}</AppText>
                  </Pressable>
                ))}
              </View>
            </View>
          ) : null}

          {modalStep === 'detail' && localSelectedType && typeData ? (
            <View style={{ minHeight: SHEET_CONTENT_MIN_HEIGHT }}>
              <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 4, marginTop: 4 }}>
                {!selectedType ? (
                  <Pressable onPress={() => setModalStep('type')} hitSlop={8} style={{ paddingRight: 4 }}>
                    <Ionicons name="chevron-back" size={22} color="#6B6B6B" />
                  </Pressable>
                ) : null}
                <AppText bold style={{ fontSize: 18, color: '#1A1A1A', marginLeft: selectedType ? 0 : 4 }}>
                  {`${typeData.emoji} ${typeData.label} 기록`}
                </AppText>
              </View>
              {dateLabel ? (
                <AppText style={{ fontSize: 12, color: colors.primary, marginBottom: 16 }}>{dateLabel}</AppText>
              ) : (
                <View style={{ marginBottom: 16 }} />
              )}
              <View style={{ marginBottom: 14 }}>
                <AppText bold style={{ fontSize: 13, color: '#6B6B6B', marginBottom: 6 }}>시간 (선택)</AppText>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                  <Pressable
                    onPress={() => {
                      setPendingTime(time || '09:00');
                      setTimePickerOpen(true);
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
                    <AppText style={{ fontSize: 15, color: time ? '#1A1A1A' : '#B0A99F' }}>
                      {time ? formatTime12h(time) : '예: 09:00'}
                    </AppText>
                    <Ionicons name="time-outline" size={14} color="#B0A99F" />
                  </Pressable>
                  {time ? (
                    <Pressable onPress={() => setTime('')}>
                      <Ionicons name="close-circle" size={20} color="#B0A99F" />
                    </Pressable>
                  ) : null}
                </View>
              </View>

              <RecordDetailForm
                typeId={localSelectedType}
                detail={detail}
                onChange={setDetail}
                note={note}
                onNoteChange={setNote}
                includePoopPhotos
                inBottomSheet
                onMemoFocus={() => bottomSheetRef.current?.snapToIndex(0)}
              />

              <Pressable
                disabled={isSaving}
                onPress={handleSubmit}
                style={{ backgroundColor: colors.primary, borderRadius: 16, paddingVertical: 16, alignItems: 'center', marginTop: 4, opacity: isSaving ? 0.6 : 1 }}
              >
                <AppText bold style={{ color: '#FFFFFF', fontSize: 16 }}>{isSaving ? '저장 중...' : '저장'}</AppText>
              </Pressable>
            </View>
          ) : null}
        </BottomSheetScrollView>
      </BottomSheet>

      {timePickerOpen ? (
        <BottomSheet
          ref={timeSheetRef}
          index={0}
          enableDynamicSizing
          enablePanDownToClose
          onClose={() => setTimePickerOpen(false)}
          backdropComponent={(props) => (
            <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />
          )}
          backgroundStyle={{ backgroundColor: '#FFFFFF', borderRadius: 24 }}
          handleIndicatorStyle={{ backgroundColor: '#D4CFC8' }}
        >
          <BottomSheetView style={{ paddingHorizontal: 20, paddingBottom: 40 }}>
            <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginBottom: 16, marginTop: 8 }}>시간 선택</AppText>
            <View style={{ borderWidth: 1, borderColor: '#E8E4DE', borderRadius: 12, overflow: 'hidden', marginBottom: 20 }}>
              <DrumRollTimePicker value={pendingTime} onChange={setPendingTime} />
            </View>
            <View style={{ flexDirection: 'row', gap: 8 }}>
              <Pressable
                onPress={() => {
                  setPendingTime(time || '09:00');
                  setTimePickerOpen(false);
                  timeSheetRef.current?.close();
                }}
                style={{ flex: 1, paddingVertical: 13, borderRadius: 14, backgroundColor: '#F5F3EF', alignItems: 'center' }}
              >
                <AppText style={{ fontSize: 14, color: '#6B6B6B' }}>취소</AppText>
              </Pressable>
              <Pressable
                onPress={() => {
                  setTime(pendingTime);
                  setTimePickerOpen(false);
                  timeSheetRef.current?.close();
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
