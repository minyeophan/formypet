import { Alert, KeyboardAvoidingView, Platform, Pressable, ScrollView, useWindowDimensions, View } from 'react-native';
import { router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useRef, useState } from 'react';
import BottomSheet, { BottomSheetBackdrop, BottomSheetView } from '@gorhom/bottom-sheet';
import { LineChart } from 'react-native-gifted-charts';
import Toast from 'react-native-toast-message';
import { format, parseISO } from 'date-fns';
import { ko } from 'date-fns/locale';
import { usePets } from '@/src/lib/pet-context';
import { getWeightHistory } from '@/src/services/records';
import { formatDate, todayString } from '@/src/lib/utils';
import { colors } from '@/src/lib/colors';
import DrumRollDatePicker from '@/src/components/shared/DrumRollDatePicker';
import AppText from '@/src/components/shared/AppText';
import NumericInputModal from '@/src/components/shared/NumericInputModal';

export default function GrowthScreen() {
  const insets = useSafeAreaInsets();
  const { width: screenWidth } = useWindowDimensions();
  const { pets, activePetId, records, addRecord, deleteRecord } = usePets();
  const pet = pets.find((p) => p.id === activePetId);

  const [showForm, setShowForm] = useState(false);
  const [date, setDate] = useState(todayString());
  const [pendingDate, setPendingDate] = useState(todayString());
  const [weightInput, setWeightInput] = useState('');
  const [numpadVisible, setNumpadVisible] = useState(false);

  const dateSheetRef = useRef<BottomSheet>(null);

  if (!pet) return null;

  const weightHistory = getWeightHistory(records, pet.id);
  const weightRecords = records
    .filter((r) => r.petId === pet.id && r.typeId === 'weight')
    .sort((a, b) => b.date.localeCompare(a.date));

  async function handleSave() {
    const w = parseFloat(weightInput);
    if (!weightInput || isNaN(w)) return;
    try {
      await addRecord({ petId: pet!.id, typeId: 'weight', date, weight: w });
      setWeightInput('');
      setDate(todayString());
      setPendingDate(todayString());
      setShowForm(false);
    } catch (error) {
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : 'Save failed' });
    }
  }

  function handleCancel() {
    setShowForm(false);
    setWeightInput('');
    setDate(todayString());
    setPendingDate(todayString());
  }

  function confirmDelete(id: string) {
    Alert.alert('체중 기록 삭제', '이 체중 기록을 삭제할까요?', [
      { text: '취소', style: 'cancel' },
      {
        text: '삭제',
        style: 'destructive',
        onPress: async () => {
          try {
            await deleteRecord(id);
          } catch (error) {
            Toast.show({ type: 'error', text1: error instanceof Error ? error.message : 'Delete failed' });
          }
        },
      },
    ]);
  }

  // y축 레이블 너비(약 40px) 제외한 차트 뷰포트 너비
  const chartWidth = screenWidth - 40;

  return (
    <KeyboardAvoidingView
      style={{ flex: 1, backgroundColor: '#F5F3EF', paddingTop: insets.top }}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      {/* 헤더 */}
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 12 }}>
        <Pressable onPress={() => router.back()} style={{ marginRight: 8 }}>
          <Ionicons name="chevron-back" size={26} color="#1A1A1A" />
        </Pressable>
        <AppText bold style={{ fontSize: 17, color: '#1A1A1A', flex: 1 }}>{pet.name}의 성장 곡선</AppText>
        <Pressable
          onPress={() => setShowForm((v) => !v)}
          style={{ backgroundColor: pet.accentColor, borderRadius: 20, paddingHorizontal: 14, paddingVertical: 7 }}
        >
          <AppText bold style={{ color: '#FFFFFF', fontSize: 13 }}>{showForm ? '취소' : '+ 추가'}</AppText>
        </Pressable>
      </View>

      <ScrollView keyboardDismissMode="on-drag" keyboardShouldPersistTaps="handled" contentContainerStyle={{ paddingBottom: 40 }}>

        {/* 체중 변화 차트 — 박스 없이 흰 배경 전체 너비 */}
        <View style={{ backgroundColor: '#FFFFFF', paddingTop: 20, paddingBottom: 4, marginBottom: 12 }}>
          <AppText bold style={{ fontSize: 15, color: '#1A1A1A', paddingHorizontal: 20, marginBottom: 12 }}>체중 변화</AppText>
          {weightHistory.length < 2 ? (
            <View style={{ marginHorizontal: 20, backgroundColor: '#F5F3EF', borderRadius: 16, padding: 32, alignItems: 'center', marginBottom: 16 }}>
              <AppText style={{ fontSize: 32, marginBottom: 8 }}>⚖️</AppText>
              <AppText style={{ fontSize: 14, color: '#B0A99F' }}>체중 기록을 2개 이상 추가해 주세요</AppText>
            </View>
          ) : (
            <LineChart
              data={weightHistory.map((d) => ({ value: d.weight }))}
              xAxisLabelTexts={weightHistory.map((d) => format(parseISO(d.date), 'M/d', { locale: ko }))}
              color={pet.accentColor}
              thickness={2.5}
              dataPointsColor={pet.accentColor}
              dataPointsRadius={5}
              startFillColor={pet.accentColor + '44'}
              endFillColor={pet.bgLight}
              areaChart
              curved
              xAxisLabelTextStyle={{ fontSize: 10, color: '#B0A99F' }}
              yAxisTextStyle={{ fontSize: 10, color: '#B0A99F' }}
              noOfSections={4}
              width={chartWidth}
              height={180}
              scrollToEnd
            />
          )}
        </View>

        {/* 기록 추가 폼 */}
        {showForm && (
          <View style={{ marginHorizontal: 20, marginBottom: 12, backgroundColor: '#FFFFFF', borderRadius: 20, padding: 20 }}>
            <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginBottom: 16 }}>체중 기록 추가</AppText>

            <AppText bold style={{ fontSize: 13, color: '#3A3A3A', marginBottom: 8 }}>날짜</AppText>
            <Pressable
              onPress={() => {
                setPendingDate(date);
                dateSheetRef.current?.expand();
              }}
              style={{
                flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                backgroundColor: '#F5F3EF', borderWidth: 1, borderColor: '#E8E4DE',
                borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12, marginBottom: 14,
              }}
            >
              <AppText style={{ fontSize: 15, color: '#1A1A1A' }}>{formatDate(date)}</AppText>
              <Ionicons name="calendar-outline" size={18} color="#B0A99F" />
            </Pressable>

            <AppText bold style={{ fontSize: 13, color: '#3A3A3A', marginBottom: 8 }}>체중 (kg)</AppText>
            <Pressable
              onPress={() => setNumpadVisible(true)}
              style={{
                backgroundColor: '#F5F3EF', borderWidth: 1, borderColor: '#E8E4DE',
                borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12,
                minHeight: 44, justifyContent: 'center', marginBottom: 16,
              }}
            >
              <AppText style={{ fontSize: 15, color: weightInput ? '#1A1A1A' : '#B0A99F' }}>
                {weightInput || '예: 4.2'}
              </AppText>
            </Pressable>

            <Pressable
              onPress={handleSave}
              style={{ backgroundColor: colors.primary, borderRadius: 14, paddingVertical: 13, alignItems: 'center' }}
            >
              <AppText bold style={{ color: '#FFFFFF', fontSize: 14 }}>저장</AppText>
            </Pressable>
          </View>
        )}

        {/* 체중 기록 목록 */}
        {weightRecords.length > 0 && (
          <View style={{ marginHorizontal: 20, backgroundColor: '#FFFFFF', borderRadius: 20, overflow: 'hidden' }}>
            <AppText bold style={{ fontSize: 14, color: '#1A1A1A', padding: 16, paddingBottom: 8 }}>체중 기록</AppText>
            {weightRecords.map((r, index) => (
              <View key={r.id}>
                {index > 0 && <View style={{ height: 1, backgroundColor: '#F0EDE8', marginHorizontal: 16 }} />}
                <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12 }}>
                  <AppText style={{ flex: 1, fontSize: 14, color: '#1A1A1A' }}>{formatDate(r.date)}</AppText>
                  <AppText bold style={{ fontSize: 15, color: pet.accentColor, marginRight: 16 }}>{r.weight}kg</AppText>
                  <Pressable onPress={() => confirmDelete(r.id)}>
                    <Ionicons name="trash-outline" size={18} color="#EF4444" />
                  </Pressable>
                </View>
              </View>
            ))}
          </View>
        )}
      </ScrollView>

      <NumericInputModal
        visible={numpadVisible}
        label="체중"
        unit="kg"
        initialValue={weightInput}
        onConfirm={(v) => { setWeightInput(v); setNumpadVisible(false); }}
        onCancel={() => setNumpadVisible(false)}
      />

      {/* 날짜 선택 BottomSheet */}
      <BottomSheet
        ref={dateSheetRef}
        index={-1}
        enableDynamicSizing
        enablePanDownToClose
        backdropComponent={(props) => (
          <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />
        )}
      >
        <BottomSheetView style={{ paddingHorizontal: 20, paddingBottom: 40 }}>
          <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginBottom: 16, marginTop: 8 }}>날짜 선택</AppText>
          <View style={{ borderWidth: 1, borderColor: '#E8E4DE', borderRadius: 12, overflow: 'hidden', marginBottom: 20 }}>
            <DrumRollDatePicker value={pendingDate} onChange={setPendingDate} />
          </View>
          <Pressable
            onPress={() => {
              setDate(pendingDate);
              dateSheetRef.current?.close();
            }}
            style={{ backgroundColor: colors.primary, borderRadius: 14, paddingVertical: 13, alignItems: 'center' }}
          >
            <AppText bold style={{ color: '#FFFFFF', fontSize: 14 }}>확인</AppText>
          </Pressable>
        </BottomSheetView>
      </BottomSheet>
    </KeyboardAvoidingView>
  );
}
