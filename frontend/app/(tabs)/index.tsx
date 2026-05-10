import { Pressable, ScrollView, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { colors } from '@/src/lib/colors';
import PetSelector from '@/src/components/home/PetSelector';
import HeroCard from '@/src/components/home/HeroCard';
import QuickRecord from '@/src/components/home/QuickRecord';
import RecentRecords from '@/src/components/home/RecentRecords';
import TodayRoutine from '@/src/components/home/TodayRoutine';
import AppText from '@/src/components/shared/AppText';

export default function HomeScreen() {
  const insets = useSafeAreaInsets();

  return (
    <View style={{ flex: 1, backgroundColor: colors.background }}>
      <ScrollView
        style={{ flex: 1 }}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 24 }}
      >
        <View style={{ paddingTop: insets.top }}>
          <View style={{ paddingHorizontal: 20, paddingTop: 8, paddingBottom: 4 }}>
            <AppText bold style={{ fontSize: 20, color: '#1A1A1A' }}>펫일기</AppText>
          </View>
          <PetSelector />
        </View>

        <HeroCard />

        <View style={{ marginHorizontal: 20, marginTop: 8, backgroundColor: colors.surface, borderRadius: 22, borderWidth: 1, borderColor: colors.border }}>
          <QuickRecord />
          <View style={{ marginHorizontal: 16, height: 1, backgroundColor: colors.border }} />
          <RecentRecords />
          <View style={{ marginHorizontal: 16, height: 1, backgroundColor: colors.border }} />
          <Pressable
            onPress={() => router.push('/records')}
            style={{ margin: 16, backgroundColor: colors.primary, borderRadius: 16, paddingVertical: 13, alignItems: 'center' }}
          >
            <AppText bold style={{ color: '#FFFFFF', fontSize: 14 }}>기록 보러가기</AppText>
          </Pressable>
        </View>

        <View style={{ marginHorizontal: 20, marginTop: 8, backgroundColor: colors.surface, borderRadius: 22, borderWidth: 1, borderColor: colors.border }}>
          <TodayRoutine />
        </View>
      </ScrollView>
    </View>
  );
}
