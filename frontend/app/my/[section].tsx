import { ComponentProps } from 'react';
import { Pressable, ScrollView, View } from 'react-native';
import { useLocalSearchParams, router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import AppText from '@/src/components/shared/AppText';
import { colors } from '@/src/lib/colors';

type IconName = ComponentProps<typeof Ionicons>['name'];

const sectionMap: Record<string, { title: string; description: string; icon: IconName }> = {
  vaccinations: {
    title: '예방접종 스케줄',
    description: '접종 일정과 다음 방문일을 차근차근 관리할 수 있도록 준비 중이에요.',
    icon: 'medical-outline',
  },
  medicine: {
    title: '투약 기록',
    description: '아이별 약 이름, 용량, 복용 이력을 한눈에 볼 수 있게 준비 중이에요.',
    icon: 'bandage-outline',
  },
  posts: {
    title: '내가 쓴 게시글',
    description: '커뮤니티에 남긴 글을 모아볼 수 있도록 정리하고 있어요.',
    icon: 'document-text-outline',
  },
  bookmarks: {
    title: '북마크한 건강 꿀팁',
    description: '다시 보고 싶은 건강 정보를 저장하고 꺼내볼 수 있게 준비 중이에요.',
    icon: 'bookmark-outline',
  },
  notices: {
    title: '공지사항',
    description: '앱 업데이트와 중요한 안내를 전할 공간이에요.',
    icon: 'megaphone-outline',
  },
  contact: {
    title: '문의하기',
    description: '불편한 점이나 도움이 필요한 내용을 보낼 수 있도록 준비 중이에요.',
    icon: 'chatbubble-ellipses-outline',
  },
  notifications: {
    title: '알림',
    description: '알림 기록을 확인할 수 있게 준비 중이에요.',
    icon: 'notifications-outline',
  },
};

export default function MySectionScreen() {
  const insets = useSafeAreaInsets();
  const { section } = useLocalSearchParams<{ section: string }>();
  const screen = sectionMap[section] ?? {
    title: '마이페이지',
    description: '요청한 메뉴를 준비하고 있어요.',
    icon: 'paw-outline' as IconName,
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.background, paddingTop: insets.top }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 12 }}>
        <Pressable onPress={() => router.back()} style={{ marginRight: 8 }}>
          <Ionicons name="chevron-back" size={26} color={colors.text} />
        </Pressable>
        <AppText bold numberOfLines={1} style={{ fontSize: 17, color: colors.text, flex: 1 }}>
          {screen.title}
        </AppText>
      </View>

      <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 36 }}>
        <View
          style={{
            backgroundColor: colors.surface,
            borderRadius: 22,
            borderWidth: 1,
            borderColor: colors.border,
            padding: 22,
          }}
        >
          <View
            style={{
              width: 62,
              height: 62,
              borderRadius: 31,
              backgroundColor: colors.surfaceSoft,
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: 16,
            }}
          >
            <Ionicons name={screen.icon} size={28} color={colors.primaryPressed} />
          </View>
          <AppText bold style={{ fontSize: 18, color: colors.text }}>
            {screen.title}
          </AppText>
          <AppText style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 22, marginTop: 8 }}>
            {screen.description}
          </AppText>
          <View
            style={{
              marginTop: 18,
              backgroundColor: colors.surfaceSoft,
              borderRadius: 16,
              borderWidth: 1,
              borderColor: colors.border,
              padding: 14,
              flexDirection: 'row',
              alignItems: 'center',
              gap: 10,
            }}
          >
            <Ionicons name="time-outline" size={20} color={colors.primaryPressed} />
            <AppText style={{ flex: 1, fontSize: 13, color: colors.textSecondary, lineHeight: 20 }}>
              아직 실제 데이터 기능은 연결되지 않았어요. 필요한 관리 화면을 순서대로 채워갈 예정이에요.
            </AppText>
          </View>
        </View>
      </ScrollView>
    </View>
  );
}
