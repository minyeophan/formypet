import { Pressable, View } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { differenceInDays, parseISO } from 'date-fns';
import Toast from 'react-native-toast-message';
import { usePets } from '@/src/lib/pet-context';
import { QUICK_TYPES } from '@/src/lib/record-types';
import { todayString } from '@/src/lib/utils';
import { colors } from '@/src/lib/colors';
import { Routine } from '@/src/types';
import AppText from '../shared/AppText';
import { formatTime12h } from '../shared/DrumRollTimePicker';
import { buildRecordFromRoutineTemplate } from '../shared/RecordDetailForm';

function isActiveToday(r: Routine): boolean {
  const today = todayString();
  if (r.startDate > today) return false;
  const dow = new Date().getDay();
  if (r.repeatType === 'daily') return true;
  if (r.repeatType === 'weekly') return r.days.includes(dow);
  if (r.repeatType === 'biweekly') {
    const diff = differenceInDays(new Date(), parseISO(r.startDate));
    return diff >= 0 && Math.floor(diff / 7) % 2 === 0 && r.days.includes(dow);
  }
  if (r.repeatType === 'monthly') {
    const start = parseISO(r.startDate);
    const now = new Date();
    if (now.getDate() !== start.getDate()) return false;
    const mDiff = (now.getFullYear() - start.getFullYear()) * 12 + (now.getMonth() - start.getMonth());
    return mDiff >= 0 && mDiff % (r.monthlyInterval ?? 1) === 0;
  }
  return false;
}

function isOverdue(time: string): boolean {
  const now = new Date();
  const [h, m] = time.split(':').map(Number);
  const slotMs = (h * 60 + m + 30) * 60 * 1000;
  const nowMs = (now.getHours() * 60 + now.getMinutes()) * 60 * 1000;
  return nowMs > slotMs;
}

interface RoutineRow {
  routine: Routine;
  routineId: string;
  label: string;
  typeId: string;
  time: string | null;
}

export default function TodayRoutine() {
  const { pets, activePetId, routines, records, addRecord, deleteRecord, openModal } = usePets();
  const pet = pets.find((p) => p.id === activePetId);
  const today = todayString();

  if (!pet) return null;

  const activeRoutines = routines.filter((r) => r.petId === pet.id && isActiveToday(r));

  const rows: RoutineRow[] = [];
  for (const r of activeRoutines) {
    if (r.times.length === 0) {
      rows.push({ routine: r, routineId: r.id, label: r.label, typeId: r.typeId, time: null });
    } else {
      for (const t of r.times) {
        rows.push({ routine: r, routineId: r.id, label: r.label, typeId: r.typeId, time: t });
      }
    }
  }
  rows.sort((a, b) => {
    if (a.time === null && b.time === null) return 0;
    if (a.time === null) return 1;
    if (b.time === null) return -1;
    return a.time.localeCompare(b.time);
  });

  function isDone(routineId: string, time: string | null): string | null {
    const rec = records.find(
      (r) =>
        r.routineId === routineId &&
        r.date === today &&
        (time === null || (r.time ?? '').startsWith(time)),
    );
    return rec?.id ?? null;
  }

  async function handleTap(row: RoutineRow) {
    const doneId = isDone(row.routineId, row.time);
    try {
      if (doneId) {
        await deleteRecord(doneId);
      } else {
        await addRecord(buildRecordFromRoutineTemplate(row.routine, today, row.time));
      }
    } catch (error) {
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : 'Routine update failed' });
    }
  }

  function handleLongPress(row: RoutineRow) {
    openModal(row.typeId, today, row.routineId, {
      ...(row.routine.detail ?? {}),
      ...(row.routine.note ? { note: row.routine.note } : {}),
      ...(row.time ? { time: row.time } : {}),
    });
  }

  const doneCount = activeRoutines.filter((r) => {
    if (r.times.length === 0) return !!isDone(r.id, null);
    return r.times.every((t) => !!isDone(r.id, t));
  }).length;

  return (
    <View style={{ padding: 16 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <AppText bold style={{ fontSize: 15, color: '#1A1A1A' }}>오늘의 루틴</AppText>
          {activeRoutines.length > 0 && (
            <View style={{
              backgroundColor: doneCount === activeRoutines.length ? colors.primary : '#E8E4DE',
              borderRadius: 10, paddingHorizontal: 7, paddingVertical: 2,
            }}>
              <AppText bold style={{ fontSize: 11, color: doneCount === activeRoutines.length ? '#FFFFFF' : '#6B6B6B' }}>
                {doneCount}/{activeRoutines.length}
              </AppText>
            </View>
          )}
        </View>
        <Pressable onPress={() => router.push('/routine')}>
          <Ionicons name="create-outline" size={20} color={colors.primary} />
        </Pressable>
      </View>

      {rows.length === 0 ? (
        <View style={{ paddingVertical: 16, alignItems: 'center' }}>
          <AppText style={{ fontSize: 32, marginBottom: 8 }}>📋</AppText>
          <AppText style={{ fontSize: 13, color: '#B0A99F', marginBottom: 12 }}>아직 등록된 루틴이 없어요</AppText>
          <Pressable
            onPress={() => router.push('/routine')}
            style={{ backgroundColor: colors.primary, borderRadius: 14, paddingHorizontal: 20, paddingVertical: 9 }}
          >
            <AppText bold style={{ fontSize: 13, color: '#FFFFFF' }}>루틴 등록하기</AppText>
          </Pressable>
        </View>
      ) : (
        rows.map((row, index) => {
          const typeInfo = QUICK_TYPES.find((t) => t.id === row.typeId);
          const doneId = isDone(row.routineId, row.time);
          const done = !!doneId;
          const overdue = !done && row.time !== null && isOverdue(row.time);

          return (
            <View key={`${row.routineId}-${row.time ?? 'notime'}`}>
              {index > 0 && <View style={{ height: 1, backgroundColor: '#F0EDE8', marginHorizontal: 4, marginVertical: 2 }} />}
              <Pressable
                onPress={() => handleTap(row)}
                onLongPress={() => handleLongPress(row)}
                style={{
                  flexDirection: 'row',
                  alignItems: 'center',
                  gap: 12,
                  paddingVertical: 8,
                  paddingHorizontal: 4,
                  borderRadius: 12,
                  backgroundColor: done ? '#F5F3EF' : 'transparent',
                }}
              >
                <View style={{
                  width: 38, height: 38, borderRadius: 11,
                  backgroundColor: typeInfo?.bg ?? '#F5F3EF',
                  alignItems: 'center', justifyContent: 'center',
                  opacity: done ? 0.5 : 1,
                }}>
                  <AppText style={{ fontSize: 19 }}>{typeInfo?.emoji ?? '📝'}</AppText>
                </View>
                <View style={{ flex: 1 }}>
                  <AppText bold style={{ fontSize: 14, color: done || overdue ? '#B0A99F' : '#1A1A1A' }}>
                    {row.label}
                  </AppText>
                  {row.time && (
                    <AppText style={{ fontSize: 12, color: overdue ? '#B0A99F' : '#6B6B6B', marginTop: 1 }}>
                      {formatTime12h(row.time)}{overdue ? ' (지남)' : ''}
                    </AppText>
                  )}
                </View>
                {/* 체크 버튼 */}
                <View style={{
                  width: 26, height: 26, borderRadius: 13,
                  backgroundColor: done ? colors.primary : 'transparent',
                  borderWidth: done ? 0 : 1.5,
                  borderColor: '#D4CFC8',
                  alignItems: 'center', justifyContent: 'center',
                }}>
                  {done && <Ionicons name="checkmark" size={15} color="#FFFFFF" />}
                </View>
              </Pressable>
            </View>
          );
        })
      )}
    </View>
  );
}
