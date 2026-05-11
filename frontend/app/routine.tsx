import { Alert, KeyboardAvoidingView, Platform, Pressable, ScrollView, Switch, View } from 'react-native';
import { TextInput } from 'react-native';
import { InteractionManager } from 'react-native';
import { router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useMemo, useRef, useState } from 'react';
import BottomSheet, { BottomSheetBackdrop, BottomSheetScrollView, BottomSheetView } from '@gorhom/bottom-sheet';
import { addDays, differenceInDays, format, parseISO } from 'date-fns';
import { ko } from 'date-fns/locale';
import { usePets } from '@/src/lib/pet-context';
import { QUICK_TYPES, SUPPORTED_QUICK_TYPES } from '@/src/lib/record-types';
import { colors } from '@/src/lib/colors';
import { getCalendarDays, todayString } from '@/src/lib/utils';
import { Routine } from '@/src/types';
import RecordDetailForm, {
  RecordDetailDraft,
  createEmptyRecordDetail,
  sanitizeRecordDetail,
} from '@/src/components/shared/RecordDetailForm';
import DrumRollDatePicker from '@/src/components/shared/DrumRollDatePicker';
import DrumRollTimePicker, { formatTime12h } from '@/src/components/shared/DrumRollTimePicker';
import AppText from '@/src/components/shared/AppText';
import { showSuccessToast } from '@/src/components/shared/AppToast';
import {
  notificationsSupported,
  requestPermission,
  scheduleRoutineNotifications,
  cancelRoutineNotifications,
} from '@/src/services/notifications';

const DAY_LABELS = ['일', '월', '화', '수', '목', '금', '토'];

type RepeatType = 'daily' | 'weekly' | 'biweekly' | 'monthly';
type RoutineFormData = Omit<Routine, 'id' | 'notificationIds'>;
type PendingEditorAction =
  | { type: 'create'; routineData: RoutineFormData }
  | { type: 'update'; routineId: string; routineData: RoutineFormData; existingRoutine: Routine | null }
  | { type: 'delete'; routineId: string; existingRoutine: Routine | null }
  | null;

const EMPTY_FORM = {
  petId: '',
  label: '',
  typeId: '',
  repeatType: 'daily' as RepeatType,
  days: [] as number[],
  startDate: todayString(),
  times: [] as string[],
  note: '',
  detail: {} as RecordDetailDraft,
  monthlyInterval: 1,
  notificationEnabled: false,
};

function isActiveOn(r: Routine, date: string): boolean {
  if (r.startDate > date) return false;
  const dow = parseISO(date).getDay();
  if (r.repeatType === 'daily') return true;
  if (r.repeatType === 'weekly') return r.days.includes(dow);
  if (r.repeatType === 'biweekly') {
    const diff = differenceInDays(parseISO(date), parseISO(r.startDate));
    if (diff < 0) return false;
    return Math.floor(diff / 7) % 2 === 0 && r.days.includes(dow);
  }
  if (r.repeatType === 'monthly') {
    const start = parseISO(r.startDate), cur = parseISO(date);
    if (cur.getDate() !== start.getDate()) return false;
    const mDiff = (cur.getFullYear() - start.getFullYear()) * 12 + (cur.getMonth() - start.getMonth());
    return mDiff >= 0 && mDiff % (r.monthlyInterval ?? 1) === 0;
  }
  return false;
}

function repeatLabel(r: Routine): string {
  if (r.repeatType === 'daily') return '매일';
  if (r.repeatType === 'weekly') return `매주 ${r.days.map((d) => DAY_LABELS[d]).join('·')}`;
  if (r.repeatType === 'biweekly') return `격주 ${r.days.map((d) => DAY_LABELS[d]).join('·')}`;
  if (r.repeatType === 'monthly') return `${r.monthlyInterval ?? 1}개월마다`;
  return '';
}

function getCompletionInfo(
  date: string,
  petId: string,
  routines: Routine[],
  records: import('@/src/types').ActivityRecord[],
) {
  const active = routines.filter((r) => r.petId === petId && isActiveOn(r, date));
  const done = active.filter((r) => records.some((rec) => rec.routineId === r.id && rec.date === date));
  return { done: done.length, total: active.length };
}

function getNextOccurrences(form: typeof EMPTY_FORM, count = 5): string[] {
  const results: string[] = [];
  let cursor = parseISO(form.startDate || todayString());
  let tries = 0;
  while (results.length < count && tries < 400) {
    const dateStr = format(cursor, 'yyyy-MM-dd');
    const dow = cursor.getDay();
    let matches = false;
    if (form.repeatType === 'daily') {
      matches = true;
    } else if (form.repeatType === 'weekly') {
      matches = form.days.includes(dow);
    } else if (form.repeatType === 'biweekly') {
      const diff = differenceInDays(cursor, parseISO(form.startDate || todayString()));
      matches = diff >= 0 && Math.floor(diff / 7) % 2 === 0 && form.days.includes(dow);
    } else if (form.repeatType === 'monthly') {
      const start = parseISO(form.startDate || todayString());
      if (cursor.getDate() === start.getDate()) {
        const mDiff = (cursor.getFullYear() - start.getFullYear()) * 12 + (cursor.getMonth() - start.getMonth());
        matches = mDiff >= 0 && mDiff % (form.monthlyInterval ?? 1) === 0;
      }
    }
    if (matches) results.push(dateStr);
    cursor = addDays(cursor, 1);
    tries++;
  }
  return results;
}

export default function RoutineScreen() {
  const insets = useSafeAreaInsets();
  const { pets, activePetId, routines, addRoutine, updateRoutine, deleteRoutine, records } = usePets();
  const pet = pets.find((p) => p.id === activePetId);

  const [calYear, setCalYear] = useState(new Date().getFullYear());
  const [calMonth, setCalMonth] = useState(new Date().getMonth());
  const [filterTypeId, setFilterTypeId] = useState<string | null>(null);
  const [selectedCalDate, setSelectedCalDate] = useState(todayString());

  const sheetRef = useRef<BottomSheet>(null);
  const dateSheetRef = useRef<BottomSheet>(null);
  const timeSheetRef = useRef<BottomSheet>(null);
  const pendingEditorActionRef = useRef<PendingEditorAction>(null);
  const isRunningEditorActionRef = useRef(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingRoutineSnapshot, setEditingRoutineSnapshot] = useState<Routine | null>(null);
  const [form, setForm] = useState({ ...EMPTY_FORM });
  const [detailDrafts, setDetailDrafts] = useState<Record<string, RecordDetailDraft>>({});
  const [labelFocused, setLabelFocused] = useState(false);
  const [pendingStartDate, setPendingStartDate] = useState(todayString());
  const [times, setTimes] = useState<string[]>([]);
  const [pendingTime, setPendingTime] = useState('09:00');
  const [editorBusy, setEditorBusy] = useState(false);
  const [pendingEditorAction, setPendingEditorAction] = useState<PendingEditorAction>(null);
  const [deleteConfirmVisible, setDeleteConfirmVisible] = useState(false);
  const [isDeletingRoutine, setIsDeletingRoutine] = useState(false);

  const petRoutines = useMemo(
    () => (pet ? routines.filter((r) => r.petId === pet.id) : []),
    [pet, routines],
  );
  const filtered = useMemo(
    () => (filterTypeId ? petRoutines.filter((r) => r.typeId === filterTypeId) : petRoutines),
    [filterTypeId, petRoutines],
  );

  const calDays = getCalendarDays(calYear, calMonth);
  const firstDow = parseISO(calDays[0]).getDay();

  const selectedDateRoutines = useMemo(
    () => petRoutines.filter((r) => isActiveOn(r, selectedCalDate)),
    [petRoutines, selectedCalDate],
  );
  const currentDetail = form.typeId ? (detailDrafts[form.typeId] ?? createEmptyRecordDetail(form.typeId)) : {};
  const deleteBusy = editorBusy || isDeletingRoutine;

  if (!pet) return null;

  function openAdd() {
    if (deleteBusy) return;
    setDeleteConfirmVisible(false);
    setIsDeletingRoutine(false);
    setEditingId(null);
    setEditingRoutineSnapshot(null);
    setForm({ ...EMPTY_FORM, petId: pet!.id, startDate: todayString(), detail: {} });
    setDetailDrafts({});
    setLabelFocused(false);
    setPendingStartDate(todayString());
    setTimes([]);
    setPendingTime('09:00');
    dateSheetRef.current?.close();
    timeSheetRef.current?.close();
    sheetRef.current?.snapToIndex(0);
  }

  function openEdit(r: Routine) {
    if (deleteBusy) return;
    setDeleteConfirmVisible(false);
    setIsDeletingRoutine(false);
    setEditingId(r.id);
    setEditingRoutineSnapshot(r);
    setForm({
      petId: r.petId,
      label: r.label,
      typeId: r.typeId,
      repeatType: r.repeatType,
      days: [...r.days],
      startDate: r.startDate,
      times: [...r.times],
      note: r.note ?? '',
      detail: r.detail ?? {},
      monthlyInterval: r.monthlyInterval ?? 1,
      notificationEnabled: notificationsSupported && r.notificationEnabled,
    });
    setDetailDrafts({ [r.typeId]: r.detail ?? createEmptyRecordDetail(r.typeId) });
    setLabelFocused(false);
    setPendingStartDate(r.startDate);
    setTimes([...r.times]);
    setPendingTime('09:00');
    dateSheetRef.current?.close();
    timeSheetRef.current?.close();
    sheetRef.current?.snapToIndex(0);
  }

  function updatePendingEditorAction(action: PendingEditorAction) {
    pendingEditorActionRef.current = action;
    setPendingEditorAction(action);
  }

  function resetEditorState() {
    setEditingId(null);
    setEditingRoutineSnapshot(null);
    setForm({ ...EMPTY_FORM, petId: pet!.id, startDate: todayString(), detail: {} });
    setDetailDrafts({});
    setTimes([]);
  }

  function runPendingEditorAction() {
    const action = pendingEditorActionRef.current;
    if (!action || isRunningEditorActionRef.current) return;
    isRunningEditorActionRef.current = true;

    InteractionManager.runAfterInteractions(async () => {
      try {
        if (action.type === 'create') {
          const newRoutine = await addRoutine(action.routineData);
          if (action.routineData.notificationEnabled) {
            const granted = await requestPermission();
            if (granted) {
              const ids = await scheduleRoutineNotifications(newRoutine, pet!.name);
              await updateRoutine(newRoutine.id, { notificationIds: ids });
            }
          }
          showSuccessToast('루틴 추가 완료');
        } else if (action.type === 'update') {
          if (action.existingRoutine) await cancelRoutineNotifications(action.existingRoutine);
          await updateRoutine(action.routineId, action.routineData);
          if (action.routineData.notificationEnabled) {
            const granted = await requestPermission();
            if (granted) {
              const updatedRoutine: Routine = { ...action.routineData, id: action.routineId, notificationIds: [] };
              const ids = await scheduleRoutineNotifications(updatedRoutine, pet!.name);
              await updateRoutine(action.routineId, { notificationIds: ids });
            }
          } else {
            await updateRoutine(action.routineId, { notificationIds: [] });
          }
        } else if (action.type === 'delete') {
          if (action.existingRoutine) await cancelRoutineNotifications(action.existingRoutine);
          await deleteRoutine(action.routineId);
          showSuccessToast('루틴 삭제 완료');
        }
      } catch (error) {
        Alert.alert('', error instanceof Error ? error.message : action.type === 'create' ? 'Create failed' : action.type === 'delete' ? 'Delete failed' : 'Update failed');
      } finally {
        isRunningEditorActionRef.current = false;
        updatePendingEditorAction(null);
        setEditorBusy(false);
        setIsDeletingRoutine(false);
        resetEditorState();
      }
    });
  }

  function handleSave() {
    if (deleteBusy) return;
    if (!form.label.trim()) { Alert.alert('', '루틴 이름을 입력해 주세요.'); return; }
    if (!form.typeId) { Alert.alert('', '타입을 선택해 주세요.'); return; }
    if (!form.petId) { Alert.alert('', '반려동물을 선택해 주세요.'); return; }
    if ((form.repeatType === 'weekly' || form.repeatType === 'biweekly') && form.days.length === 0) {
      Alert.alert('', '요일을 하나 이상 선택해 주세요.'); return;
    }

    const routineData = {
      ...form,
      label: form.label.trim(),
      times,
      note: form.note.trim() || undefined,
      detail: sanitizeRecordDetail(form.typeId, currentDetail),
      notificationEnabled: notificationsSupported && form.notificationEnabled,
    };

    if (editingId) {
      const existing = routines.find((r) => r.id === editingId);
      updatePendingEditorAction({ type: 'update', routineId: editingId, routineData, existingRoutine: existing ?? editingRoutineSnapshot });
    } else {
      updatePendingEditorAction({ type: 'create', routineData });
    }
    setEditorBusy(true);
    dateSheetRef.current?.close();
    timeSheetRef.current?.close();
    sheetRef.current?.close();
  }

  function handleDelete() {
    if (deleteBusy) return;
    setDeleteConfirmVisible(true);
  }

  function confirmRoutineDelete(id: string) {
    if (isDeletingRoutine) return;
    const existingRoutine = editingRoutineSnapshot ?? routines.find((r) => r.id === id) ?? null;
    setIsDeletingRoutine(true);
    dateSheetRef.current?.close();
    timeSheetRef.current?.close();
    updatePendingEditorAction({ type: 'delete', routineId: id, existingRoutine });
    sheetRef.current?.close();
  }

  function handleEditorClose() {
    if (pendingEditorActionRef.current) {
      runPendingEditorAction();
      return;
    }
    setDeleteConfirmVisible(false);
    setIsDeletingRoutine(false);
    resetEditorState();
  }

  function toggleDay(d: number) {
    if (deleteBusy) return;
    setForm((f) => ({
      ...f,
      days: f.days.includes(d) ? f.days.filter((x) => x !== d) : [...f.days, d],
    }));
  }

  function setDayPreset(preset: 'all' | 'weekday' | 'weekend') {
    if (deleteBusy) return;
    const next = preset === 'all' ? [0,1,2,3,4,5,6] : preset === 'weekday' ? [1,2,3,4,5] : [0,6];
    setForm((f) => ({ ...f, days: next }));
  }

  function isDayPresetSelected(preset: 'all' | 'weekday' | 'weekend') {
    const target = preset === 'all' ? [0,1,2,3,4,5,6] : preset === 'weekday' ? [1,2,3,4,5] : [0,6];
    return form.days.length === target.length && target.every((day) => form.days.includes(day));
  }

  function changeType(typeId: string) {
    if (deleteBusy) return;
    const nextDetail = detailDrafts[typeId] ?? createEmptyRecordDetail(typeId);
    setDetailDrafts((drafts) => ({
      ...drafts,
      [form.typeId]: currentDetail,
      [typeId]: nextDetail,
    }));
    setForm((f) => ({
      ...f,
      typeId,
      detail: nextDetail,
    }));
  }

  const nextOccurrences = getNextOccurrences(form);

  const prevMonth = () => {
    if (calMonth === 0) { setCalYear((y) => y - 1); setCalMonth(11); }
    else setCalMonth((m) => m - 1);
  };
  const nextMonth = () => {
    if (calMonth === 11) { setCalYear((y) => y + 1); setCalMonth(0); }
    else setCalMonth((m) => m + 1);
  };

  return (
    <KeyboardAvoidingView
      style={{ flex: 1, backgroundColor: colors.background, paddingTop: insets.top }}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      {/* 헤더 */}
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 12 }}>
        <Pressable onPress={() => router.back()} style={{ marginRight: 8 }}>
          <Ionicons name="chevron-back" size={26} color="#1A1A1A" />
        </Pressable>
        <AppText bold style={{ fontSize: 17, color: '#1A1A1A', flex: 1 }}>{pet.name} 루틴 관리</AppText>
      </View>

      <ScrollView keyboardDismissMode="on-drag" contentContainerStyle={{ paddingBottom: 40 }}>
        {/* 완료 캘린더 */}
        <View style={{ marginHorizontal: 20, marginBottom: 12, backgroundColor: colors.surface, borderRadius: 22, borderWidth: 1, borderColor: colors.border, padding: 16 }}>
          {/* 월 네비게이션 */}
          {(() => {
            const now = new Date();
            const isViewingThisMonth = calYear === now.getFullYear() && calMonth === now.getMonth();
            return (
              <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
                <Pressable onPress={prevMonth} style={{ padding: 8 }}>
                  <AppText style={{ fontSize: 18, color: '#6B6B6B' }}>‹</AppText>
                </Pressable>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                  <AppText bold style={{ fontSize: 16, color: '#1A1A1A' }}>
                    {calYear}년 {calMonth + 1}월
                  </AppText>
                  {!isViewingThisMonth && (
                    <Pressable
                      onPress={() => { setCalYear(now.getFullYear()); setCalMonth(now.getMonth()); setSelectedCalDate(todayString()); }}
                      style={{ paddingHorizontal: 10, paddingVertical: 3, borderRadius: 12, backgroundColor: pet.accentColor + '22', borderWidth: 1, borderColor: pet.accentColor + '55' }}
                    >
                      <AppText style={{ fontSize: 11, color: pet.accentColor }}>오늘</AppText>
                    </Pressable>
                  )}
                </View>
                <Pressable onPress={nextMonth} style={{ padding: 8 }}>
                  <AppText style={{ fontSize: 18, color: '#6B6B6B' }}>›</AppText>
                </Pressable>
              </View>
            );
          })()}

          {/* 요일 헤더 */}
          <View style={{ flexDirection: 'row', marginBottom: 4 }}>
            {DAY_LABELS.map((d, i) => (
              <View key={d} style={{ flex: 1, alignItems: 'center' }}>
                <AppText style={{ fontSize: 12, color: i === 0 ? '#EF4444' : i === 6 ? '#3B82F6' : '#B0A99F' }}>{d}</AppText>
              </View>
            ))}
          </View>

          {/* 날짜 그리드 */}
          {(() => {
            const cells: (string | null)[] = [...Array(firstDow).fill(null), ...calDays];
            while (cells.length % 7 !== 0) cells.push(null);
            const weeks: (string | null)[][] = [];
            for (let i = 0; i < cells.length; i += 7) weeks.push(cells.slice(i, i + 7));
            return weeks.map((week, wi) => (
              <View key={wi} style={{ flexDirection: 'row' }}>
                {week.map((dateStr, di) => {
                  if (!dateStr) return <View key={di} style={{ flex: 1, height: 40 }} />;
                  const { done, total } = getCompletionInfo(dateStr, pet.id, petRoutines, records);
                  const day = parseInt(dateStr.slice(8), 10);
                  const isToday = dateStr === todayString();
                  const isSelected = dateStr === selectedCalDate;
                  const isSun = di === 0;
                  const isSat = di === 6;

                  // 선택 여부와 무관하게 완료율 점 색상을 계산한다.
                  let dotColor = 'transparent';
                  if (total > 0) {
                    const rate = done / total;
                    if (rate === 1) dotColor = pet.accentColor;
                    else if (rate >= 0.5) dotColor = pet.accentColor + '99';
                    else dotColor = pet.accentColor + '44';
                  }

                  return (
                    <Pressable
                      key={di}
                      onPress={() => setSelectedCalDate(dateStr)}
                      style={{ flex: 1, height: 40, alignItems: 'center', justifyContent: 'center' }}
                    >
                      <View style={{
                        width: 32, height: 32, borderRadius: 16,
                        alignItems: 'center', justifyContent: 'center',
                        backgroundColor: isSelected ? pet.accentColor : 'transparent',
                        borderWidth: isToday && !isSelected ? 1.5 : 0,
                        borderColor: pet.accentColor,
                      }}>
                        <AppText bold={isSelected} style={{
                          fontSize: 14,
                          color: isSelected ? '#FFFFFF' : isSun ? '#EF4444' : isSat ? '#3B82F6' : '#1A1A1A',
                        }}>
                          {day}
                        </AppText>
                      </View>
                      {/* 완료율 점 */}
                      {dotColor !== 'transparent' && !isSelected
                        ? <View style={{ width: 4, height: 4, borderRadius: 2, backgroundColor: dotColor, marginTop: 1 }} />
                        : <View style={{ width: 4, height: 4, marginTop: 1 }} />
                      }
                    </Pressable>
                  );
                })}
              </View>
            ));
          })()}

          {/* 선택된 날짜 루틴 목록 */}
          <View style={{ marginTop: 12, borderTopWidth: 1, borderTopColor: '#F0EDE8', paddingTop: 12, minHeight: 74 }}>
            <AppText bold style={{ fontSize: 13, color: '#1A1A1A', marginBottom: 8 }}>
              {format(parseISO(selectedCalDate), 'M월 d일(E)', { locale: ko })}
            </AppText>
            {selectedDateRoutines.length === 0 ? (
              <AppText style={{ fontSize: 13, color: '#B0A99F' }}>활성 루틴이 없어요</AppText>
            ) : (
              selectedDateRoutines.map((r, index) => {
                const typeInfo = QUICK_TYPES.find((t) => t.id === r.typeId);
                const isDone = records.some((rec) => rec.routineId === r.id && rec.date === selectedCalDate);
                return (
                  <View key={r.id}>
                    {index > 0 && <View style={{ height: 1, backgroundColor: '#F5F3EF', marginVertical: 4 }} />}
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                      <AppText style={{ fontSize: 18 }}>{typeInfo?.emoji ?? '📌'}</AppText>
                      <AppText style={{ flex: 1, fontSize: 13, color: isDone ? '#B0A99F' : '#1A1A1A' }}>{r.label}</AppText>
                      {r.times.length > 0 && (
                        <AppText style={{ fontSize: 12, color: '#B0A99F', marginRight: 6 }}>{r.times[0]}</AppText>
                      )}
                      <Ionicons
                        name={isDone ? 'checkmark-circle' : 'ellipse-outline'}
                        size={20}
                        color={isDone ? pet.accentColor : '#D4CFC8'}
                      />
                    </View>
                  </View>
                );
              })
            )}
          </View>
        </View>

        {/* 타입 필터 */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={{ marginBottom: 8 }}
          contentContainerStyle={{ paddingHorizontal: 20, gap: 8 }}
        >
          <Pressable
            onPress={() => setFilterTypeId(null)}
            style={{ paddingHorizontal: 14, paddingVertical: 7, borderRadius: 20, backgroundColor: filterTypeId === null ? colors.primary : '#FFFFFF', borderWidth: 1, borderColor: filterTypeId === null ? colors.primary : '#E8E4DE' }}
          >
            <AppText style={{ fontSize: 13, color: filterTypeId === null ? '#FFFFFF' : '#3A3A3A' }}>전체</AppText>
          </Pressable>
          {SUPPORTED_QUICK_TYPES.map((t) => (
            <Pressable
              key={t.id}
              onPress={() => setFilterTypeId(filterTypeId === t.id ? null : t.id)}
              style={{ paddingHorizontal: 12, paddingVertical: 7, borderRadius: 20, backgroundColor: filterTypeId === t.id ? colors.primary : '#FFFFFF', borderWidth: 1, borderColor: filterTypeId === t.id ? colors.primary : '#E8E4DE', flexDirection: 'row', alignItems: 'center', gap: 4 }}
            >
              <AppText style={{ fontSize: 13 }}>{t.emoji}</AppText>
              <AppText style={{ fontSize: 13, color: filterTypeId === t.id ? '#FFFFFF' : '#3A3A3A' }}>{t.label}</AppText>
            </Pressable>
          ))}
        </ScrollView>

        {/* 추가 버튼 */}
          <Pressable
            disabled={deleteBusy}
            onPress={openAdd}
            style={{ marginHorizontal: 20, marginBottom: 12, backgroundColor: colors.primary, borderRadius: 16, paddingVertical: 13, alignItems: 'center', opacity: deleteBusy ? 0.6 : 1 }}
        >
          <AppText bold style={{ color: '#FFFFFF', fontSize: 14 }}>+ 새 루틴 추가</AppText>
        </Pressable>

        {/* 루틴 목록 */}
        {filtered.length === 0 ? (
          <View style={{ marginHorizontal: 20, backgroundColor: colors.surface, borderRadius: 22, borderWidth: 1, borderColor: colors.border, padding: 32, alignItems: 'center', minHeight: 112 }}>
            <AppText style={{ fontSize: 32, marginBottom: 8 }}>🐾</AppText>
            <AppText style={{ fontSize: 14, color: colors.muted }}>등록된 루틴이 없어요. 새 루틴을 추가해 보세요.</AppText>
          </View>
        ) : (
          <View style={{ marginHorizontal: 20, backgroundColor: colors.surface, borderRadius: 22, borderWidth: 1, borderColor: colors.border, overflow: 'hidden' }}>
            {filtered.map((r, index) => {
              const typeInfo = QUICK_TYPES.find((t) => t.id === r.typeId);
              return (
                <View key={r.id}>
                  {index > 0 && <View style={{ height: 1, backgroundColor: colors.border, marginHorizontal: 16 }} />}
                  <Pressable
                    disabled={deleteBusy}
                    onPress={() => openEdit(r)}
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 16, paddingVertical: 14 }}
                  >
                    <View style={{ width: 38, height: 38, borderRadius: 11, backgroundColor: typeInfo?.bg ?? colors.surfaceSoft, borderWidth: 1, borderColor: colors.border, alignItems: 'center', justifyContent: 'center' }}>
                      <AppText style={{ fontSize: 19 }}>{typeInfo?.emoji ?? '📌'}</AppText>
                    </View>
                    <View style={{ flex: 1 }}>
                      <AppText bold style={{ fontSize: 14, color: '#1A1A1A' }}>{r.label}</AppText>
                      <AppText style={{ fontSize: 12, color: '#B0A99F', marginTop: 2 }}>
                        {repeatLabel(r)}
                        {r.times.length > 0 ? `  ${r.times.map(formatTime12h).join(', ')}` : ''}
                        {r.notificationEnabled ? '  알림' : ''}
                      </AppText>
                    </View>
                    <Ionicons name="chevron-forward" size={18} color="#B0A99F" />
                  </Pressable>
                </View>
              );
            })}
          </View>
        )}
      </ScrollView>

      {/* 추가/수정 BottomSheet */}
      <BottomSheet
        ref={sheetRef}
        index={-1}
        snapPoints={['90%']}
        enablePanDownToClose={!isDeletingRoutine}
        onClose={handleEditorClose}
        backdropComponent={(props) => (
          <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} pressBehavior={isDeletingRoutine ? 'none' : 'close'} />
        )}
        backgroundStyle={{ backgroundColor: '#FFFFFF', borderRadius: 24 }}
        handleIndicatorStyle={{ backgroundColor: '#D4CFC8' }}
        keyboardBehavior="interactive"
        keyboardBlurBehavior="restore"
      >
        <BottomSheetScrollView keyboardDismissMode="on-drag" contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 60 }}>
          {/* 헤더 */}
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginVertical: 12 }}>
            <AppText bold style={{ fontSize: 17, color: '#1A1A1A' }}>{editingId ? '루틴 수정' : '새 루틴 추가'}</AppText>
          </View>

          {/* 반려동물 */}
          <AppText bold style={{ fontSize: 13, color: '#6B6B6B', marginBottom: 8 }}>반려동물</AppText>
          <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap', marginBottom: 16 }}>
            {pets.map((p) => (
              <Pressable
                key={p.id}
                disabled={deleteBusy}
                onPress={() => setForm((f) => ({ ...f, petId: p.id }))}
                style={{ paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20, backgroundColor: form.petId === p.id ? colors.primary : '#F5F3EF', borderWidth: 1, borderColor: form.petId === p.id ? colors.primary : '#E8E4DE' }}
              >
                <AppText style={{ fontSize: 13, color: form.petId === p.id ? '#FFFFFF' : '#3A3A3A' }}>{p.name}</AppText>
              </Pressable>
            ))}
          </View>

          {/* 루틴 이름 */}
          <AppText bold style={{ fontSize: 13, color: '#6B6B6B', marginBottom: 8 }}>루틴 이름</AppText>
          <TextInput
            value={form.label}
            editable={!deleteBusy}
            onChangeText={(v) => setForm((f) => ({ ...f, label: v }))}
            placeholder="예: 아침 식사, 약 복용"
            placeholderTextColor="#B0A99F"
            returnKeyType="done"
            blurOnSubmit
            onFocus={() => setLabelFocused(true)}
            onBlur={() => setLabelFocused(false)}
            style={{
              backgroundColor: '#F5F3EF',
              borderRadius: 12,
              borderWidth: 1.5,
              borderColor: labelFocused ? colors.primary : '#F5F3EF',
              paddingHorizontal: 16,
              paddingVertical: 12,
              fontSize: 15,
              color: '#1A1A1A',
              marginBottom: 16,
            }}
          />

          {/* 타입 */}
          <AppText bold style={{ fontSize: 13, color: '#6B6B6B', marginBottom: 8 }}>타입</AppText>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 16 }}>
            {SUPPORTED_QUICK_TYPES.map((t) => (
              <Pressable
                key={t.id}
                disabled={deleteBusy}
                onPress={() => changeType(t.id)}
                style={{ width: 60, height: 60, borderRadius: 14, backgroundColor: form.typeId === t.id ? t.bg : '#F5F3EF', alignItems: 'center', justifyContent: 'center', gap: 2, borderWidth: 2, borderColor: form.typeId === t.id ? colors.primary : 'transparent' }}
              >
                <AppText style={{ fontSize: 20 }}>{t.emoji}</AppText>
                <AppText style={{ fontSize: 10, color: '#6B6B6B' }}>{t.label}</AppText>
              </Pressable>
            ))}
          </View>

          {/* 반복 주기 */}
          <AppText bold style={{ fontSize: 13, color: '#6B6B6B', marginBottom: 8 }}>반복 주기</AppText>
          <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
            {([
              { id: 'daily', label: '매일' },
              { id: 'weekly', label: '매주' },
              { id: 'biweekly', label: '격주' },
              { id: 'monthly', label: 'n개월마다' },
            ] as { id: RepeatType; label: string }[]).map((rt) => (
              <Pressable
                key={rt.id}
                disabled={deleteBusy}
                onPress={() => setForm((f) => ({ ...f, repeatType: rt.id }))}
                style={{ paddingHorizontal: 18, paddingVertical: 9, borderRadius: 20, backgroundColor: form.repeatType === rt.id ? colors.primary : '#F5F3EF', borderWidth: 1, borderColor: form.repeatType === rt.id ? colors.primary : '#E8E4DE' }}
              >
                <AppText style={{ fontSize: 13, color: form.repeatType === rt.id ? '#FFFFFF' : '#3A3A3A' }}>{rt.label}</AppText>
              </Pressable>
            ))}
          </View>

          {/* 요일 (weekly/biweekly) */}
          {(form.repeatType === 'weekly' || form.repeatType === 'biweekly') && (
            <>
              {form.repeatType === 'biweekly' && (
                <AppText style={{ fontSize: 12, color: '#B0A99F', marginBottom: 8 }}>2주마다 선택한 요일에 반복돼요.</AppText>
              )}
              <View style={{ flexDirection: 'row', gap: 6, marginBottom: 8 }}>
                {(['all', 'weekday', 'weekend'] as const).map((p) => {
                  const selected = isDayPresetSelected(p);
                  return (
                    <Pressable
                      key={p}
                      disabled={deleteBusy}
                      onPress={() => setDayPreset(p)}
                      style={{ paddingHorizontal: 12, paddingVertical: 6, borderRadius: 14, backgroundColor: selected ? colors.primary : '#F5F3EF', borderWidth: 1, borderColor: selected ? colors.primary : '#E8E4DE' }}
                    >
                      <AppText style={{ fontSize: 12, color: selected ? '#FFFFFF' : '#6B6B6B' }}>{p === 'all' ? '전체' : p === 'weekday' ? '평일' : '주말'}</AppText>
                    </Pressable>
                  );
                })}
              </View>
              <View style={{ flexDirection: 'row', gap: 6, marginBottom: 16 }}>
                {DAY_LABELS.map((d, i) => (
                  <Pressable
                    key={d}
                    disabled={deleteBusy}
                    onPress={() => toggleDay(i)}
                    style={{ flex: 1, aspectRatio: 1, borderRadius: 20, backgroundColor: form.days.includes(i) ? colors.primary : '#F5F3EF', alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderColor: form.days.includes(i) ? colors.primary : '#E8E4DE' }}
                  >
                    <AppText style={{ fontSize: 13, color: form.days.includes(i) ? '#FFFFFF' : '#3A3A3A' }}>{d}</AppText>
                  </Pressable>
                ))}
              </View>
            </>
          )}

          {/* n개월마다 스테퍼 */}
          {form.repeatType === 'monthly' && (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 16, marginBottom: 16, justifyContent: 'center' }}>
              <Pressable
                onPress={() => setForm((f) => ({ ...f, monthlyInterval: Math.max(1, (f.monthlyInterval ?? 1) - 1) }))}
                disabled={deleteBusy}
                style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: '#F5F3EF', alignItems: 'center', justifyContent: 'center' }}
              >
                <AppText style={{ fontSize: 20, color: '#6B6B6B' }}>-</AppText>
              </Pressable>
              <AppText bold style={{ fontSize: 17, color: '#1A1A1A', minWidth: 80, textAlign: 'center' }}>
                {form.monthlyInterval ?? 1}개월마다
              </AppText>
              <Pressable
                onPress={() => setForm((f) => ({ ...f, monthlyInterval: Math.min(12, (f.monthlyInterval ?? 1) + 1) }))}
                disabled={deleteBusy}
                style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: '#F5F3EF', alignItems: 'center', justifyContent: 'center' }}
              >
                <AppText style={{ fontSize: 20, color: '#6B6B6B' }}>+</AppText>
              </Pressable>
            </View>
          )}

          {/* 시작 날짜 */}
          <AppText bold style={{ fontSize: 13, color: '#6B6B6B', marginBottom: 8 }}>시작 날짜</AppText>
          <Pressable
            disabled={deleteBusy}
            onPress={() => {
              setPendingStartDate(form.startDate);
              dateSheetRef.current?.expand();
            }}
            style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: '#F5F3EF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12, marginBottom: 16 }}
          >
            <AppText style={{ fontSize: 15, color: '#1A1A1A' }}>
              {format(parseISO(form.startDate), 'yyyy년 M월 d일', { locale: ko })}
            </AppText>
            <Ionicons name="calendar-outline" size={18} color="#B0A99F" />
          </Pressable>

          {/* 시간 설정 */}
          <AppText bold style={{ fontSize: 13, color: '#6B6B6B', marginBottom: 8 }}>시간 설정</AppText>

          {/* 추가된 시간 행 */}
          {times.map((t, i) => (
            <View
              key={t}
              style={{
                flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                backgroundColor: '#F5F3EF', borderRadius: 12,
                paddingHorizontal: 16, paddingVertical: 12, marginBottom: 8,
              }}
            >
              <AppText style={{ fontSize: 15, color: '#1A1A1A' }}>{formatTime12h(t)}</AppText>
              <Pressable onPress={() => setTimes((prev) => prev.filter((_, idx) => idx !== i))}>
                <Ionicons name="close" size={18} color="#B0A99F" />
              </Pressable>
            </View>
          ))}

          {/* 시간 추가 버튼 (최대 3개) */}
          {times.length < 3 && (
            <>
              <Pressable
                onPress={() => {
                  setPendingTime('09:00');
                  timeSheetRef.current?.expand();
                }}
                disabled={deleteBusy}
                style={{
                  flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                  backgroundColor: '#F5F3EF', borderRadius: 12,
                  paddingHorizontal: 16, paddingVertical: 12,
                  marginBottom: 16,
                }}
              >
                <AppText style={{ fontSize: 15, color: '#B0A99F' }}>시간 추가</AppText>
                <Ionicons name="time-outline" size={18} color="#B0A99F" />
              </Pressable>
            </>
          )}

          {times.length >= 3 && <View style={{ marginBottom: 16 }} />}

          {/* 예정일 미리보기 */}
          {nextOccurrences.length > 0 && (
            <>
              <AppText bold style={{ fontSize: 13, color: '#6B6B6B', marginBottom: 8 }}>예정일 미리보기</AppText>
              <View style={{ backgroundColor: '#F5F3EF', borderRadius: 12, padding: 12, marginBottom: 16 }}>
                {nextOccurrences.map((d) => (
                  <AppText key={d} style={{ fontSize: 13, color: '#6B6B6B', marginBottom: 4 }}>
                    {format(parseISO(d), 'yyyy년 M월 d일(E)', { locale: ko })}
                  </AppText>
                ))}
              </View>
            </>
          )}

          {form.typeId ? (
            <>
              <AppText bold style={{ fontSize: 13, color: '#6B6B6B', marginBottom: 8 }}>기록 템플릿</AppText>
              <View style={{ marginBottom: 16 }}>
                <RecordDetailForm
                  typeId={form.typeId}
                  detail={currentDetail}
                  onChange={(next) => {
                    setDetailDrafts((drafts) => ({ ...drafts, [form.typeId]: next }));
                    setForm((f) => ({ ...f, detail: next }));
                  }}
                  note={form.note}
                  onNoteChange={(note) => setForm((f) => ({ ...f, note }))}
                  includePoopPhotos={false}
                  inBottomSheet
                />
              </View>
            </>
          ) : null}

          {/* 알림 */}
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
            <View>
              <AppText bold style={{ fontSize: 13, color: '#6B6B6B' }}>알림 받기</AppText>
              <AppText style={{ fontSize: 11, color: '#B0A99F', marginTop: 2 }}>시간 설정이 있을 때만 작동해요.</AppText>
            </View>
            <Switch
              value={notificationsSupported && form.notificationEnabled}
              disabled={deleteBusy || !notificationsSupported}
              onValueChange={(v) => setForm((f) => ({ ...f, notificationEnabled: notificationsSupported && v }))}
              trackColor={{ false: '#E8E4DE', true: colors.primary }}
              thumbColor="#FFFFFF"
            />
          </View>

          <Pressable
            disabled={deleteBusy || deleteConfirmVisible}
            onPress={handleSave}
            style={{ backgroundColor: colors.primary, borderRadius: 14, paddingVertical: 13, alignItems: 'center', opacity: deleteBusy || deleteConfirmVisible ? 0.6 : 1 }}
          >
            <AppText bold style={{ color: '#FFFFFF', fontSize: 14 }}>{editorBusy && pendingEditorAction ? '저장 중...' : '루틴 저장'}</AppText>
          </Pressable>
          {editingId && deleteConfirmVisible ? (
            <View style={{ marginTop: 10, borderRadius: 14, borderWidth: 1, borderColor: '#FCA5A5', backgroundColor: '#FEF2F2', padding: 12 }}>
              <AppText bold style={{ fontSize: 13, color: '#991B1B', marginBottom: 4 }}>루틴을 삭제할까요?</AppText>
              <AppText style={{ fontSize: 12, color: '#7F1D1D', marginBottom: 12 }}>삭제한 루틴은 되돌릴 수 없어요.</AppText>
              <View style={{ flexDirection: 'row', gap: 8 }}>
                <Pressable
                  disabled={isDeletingRoutine}
                  onPress={() => setDeleteConfirmVisible(false)}
                  style={{ flex: 1, borderRadius: 12, paddingVertical: 12, alignItems: 'center', backgroundColor: '#FFFFFF', borderWidth: 1, borderColor: '#FCA5A5', opacity: isDeletingRoutine ? 0.6 : 1 }}
                >
                  <AppText bold style={{ color: '#7F1D1D', fontSize: 13 }}>취소</AppText>
                </Pressable>
                <Pressable
                  disabled={isDeletingRoutine}
                  onPress={() => confirmRoutineDelete(editingId)}
                  style={{ flex: 1, borderRadius: 12, paddingVertical: 12, alignItems: 'center', backgroundColor: '#EF4444', opacity: isDeletingRoutine ? 0.6 : 1 }}
                >
                  <AppText bold style={{ color: '#FFFFFF', fontSize: 13 }}>{isDeletingRoutine ? '삭제 중...' : '삭제'}</AppText>
                </Pressable>
              </View>
            </View>
          ) : editingId ? (
            <Pressable
              disabled={deleteBusy}
              onPress={handleDelete}
              style={{ borderRadius: 14, paddingVertical: 13, alignItems: 'center', marginTop: 10, borderWidth: 1, borderColor: '#EF4444', opacity: deleteBusy ? 0.6 : 1 }}
            >
              <AppText bold style={{ color: '#EF4444', fontSize: 14 }}>루틴 삭제</AppText>
            </Pressable>
          ) : null}
        </BottomSheetScrollView>
      </BottomSheet>
      <BottomSheet
        ref={dateSheetRef}
        index={-1}
        enableDynamicSizing
        enablePanDownToClose
        backdropComponent={(props) => (
          <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />
        )}
        backgroundStyle={{ backgroundColor: '#FFFFFF', borderRadius: 24 }}
        handleIndicatorStyle={{ backgroundColor: '#D4CFC8' }}
      >
        <BottomSheetView style={{ paddingHorizontal: 20, paddingBottom: 40 }}>
          <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginBottom: 16, marginTop: 8 }}>시작 날짜 선택</AppText>
          <View style={{ borderWidth: 1, borderColor: '#E8E4DE', borderRadius: 12, overflow: 'hidden', marginBottom: 20 }}>
            <DrumRollDatePicker value={pendingStartDate} onChange={setPendingStartDate} />
          </View>
          <View style={{ flexDirection: 'row', gap: 8 }}>
            <Pressable
              onPress={() => {
                setPendingStartDate(form.startDate);
                dateSheetRef.current?.close();
              }}
              style={{ flex: 1, backgroundColor: '#F5F3EF', borderRadius: 14, paddingVertical: 13, alignItems: 'center' }}
            >
              <AppText style={{ color: '#6B6B6B', fontSize: 14 }}>취소</AppText>
            </Pressable>
            <Pressable
              onPress={() => {
                setForm((f) => ({ ...f, startDate: pendingStartDate }));
                dateSheetRef.current?.close();
              }}
              style={{ flex: 2, backgroundColor: colors.primary, borderRadius: 14, paddingVertical: 13, alignItems: 'center' }}
            >
              <AppText bold style={{ color: '#FFFFFF', fontSize: 14 }}>확인</AppText>
            </Pressable>
          </View>
        </BottomSheetView>
      </BottomSheet>

      <BottomSheet
        ref={timeSheetRef}
        index={-1}
        enableDynamicSizing
        enablePanDownToClose
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
                setPendingTime('09:00');
                timeSheetRef.current?.close();
              }}
              style={{ flex: 1, backgroundColor: '#F5F3EF', borderRadius: 14, paddingVertical: 13, alignItems: 'center' }}
            >
              <AppText style={{ color: '#6B6B6B', fontSize: 14 }}>취소</AppText>
            </Pressable>
            <Pressable
              onPress={() => {
                if (!times.includes(pendingTime)) setTimes((prev) => [...prev, pendingTime].sort());
                setPendingTime('09:00');
                timeSheetRef.current?.close();
              }}
              style={{ flex: 2, backgroundColor: colors.primary, borderRadius: 14, paddingVertical: 13, alignItems: 'center' }}
            >
              <AppText bold style={{ color: '#FFFFFF', fontSize: 14 }}>추가</AppText>
            </Pressable>
          </View>
        </BottomSheetView>
      </BottomSheet>
    </KeyboardAvoidingView>
  );
}
