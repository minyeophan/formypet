import { Link, Stack } from 'expo-router';
import { View } from 'react-native';
import AppText from '@/src/components/shared/AppText';

export default function NotFoundScreen() {
  return (
    <>
      <Stack.Screen options={{ title: '페이지 없음' }} />
      <View className="flex-1 items-center justify-center p-5 bg-[#F5F3EF]">
        <AppText bold className="text-xl text-[#1A1A1A]">존재하지 않는 페이지예요.</AppText>
        <Link href="/" className="mt-4">
          <AppText className="text-sm text-[#F4A460]">홈으로 돌아가기</AppText>
        </Link>
      </View>
    </>
  );
}
