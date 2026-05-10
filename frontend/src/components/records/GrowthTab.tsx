import { LineChart } from 'react-native-gifted-charts';
import { ScrollView, View } from 'react-native';
import { usePets } from '@/src/lib/pet-context';
import { getWeightHistory, getRecordsByPet, groupRecordsByDate } from '@/src/services/records';
import { formatDateShort } from '@/src/lib/utils';
import { parseISO, format } from 'date-fns';
import { ko } from 'date-fns/locale';
import RecordList from './RecordList';
import AppText from '../shared/AppText';

export default function GrowthTab() {
  const { pets, activePetId, records } = usePets();
  const pet = pets.find((p) => p.id === activePetId);
  if (!pet) return null;

  const weightHistory = getWeightHistory(records, pet.id);
  const weightRecords = getRecordsByPet(records, pet.id).filter((r) => r.typeId === 'weight');
  const sections = groupRecordsByDate(weightRecords);

  return (
    <ScrollView contentContainerStyle={{ paddingBottom: 24 }}>
      {/* 체중 차트 */}
      <View style={{ marginHorizontal: 20, marginTop: 20, marginBottom: 8 }}>
        <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginBottom: 16 }}>체중 변화</AppText>

        {weightHistory.length < 2 ? (
          <View
            style={{
              backgroundColor: '#F5F3EF',
              borderRadius: 16,
              padding: 32,
              alignItems: 'center',
            }}
          >
            <AppText style={{ fontSize: 32, marginBottom: 8 }}>⚖️</AppText>
            <AppText style={{ fontSize: 14, color: '#B0A99F' }}>체중 기록이 2개 이상이면 그래프가 표시돼요</AppText>
          </View>
        ) : (
          <View style={{ backgroundColor: '#FFFFFF', borderRadius: 16, padding: 16 }}>
            <LineChart
              data={weightHistory.map((d) => ({ value: d.weight }))}
              xAxisLabelTexts={weightHistory.map((d) =>
                format(parseISO(d.date), 'M/d', { locale: ko })
              )}
              color={pet.accentColor}
              thickness={2.5}
              dataPointsColor={pet.accentColor}
              dataPointsRadius={5}
              startFillColor={pet.accentColor + '44'}
              endFillColor={pet.bgLight}
              areaChart
              curved
              hideDataPoints={false}
              xAxisLabelTextStyle={{ fontSize: 10, color: '#B0A99F' }}
              yAxisTextStyle={{ fontSize: 10, color: '#B0A99F' }}
              noOfSections={4}
              width={280}
              height={160}
            />
          </View>
        )}
      </View>

      {/* 체중 기록 목록 */}
      <View style={{ paddingHorizontal: 20 }}>
        <AppText bold style={{ fontSize: 15, color: '#1A1A1A', marginTop: 8, marginBottom: 4 }}>
          체중 기록
        </AppText>
      </View>
      <RecordList sections={sections} />
    </ScrollView>
  );
}
