import { ComponentProps, useState } from 'react';
import { Image, Pressable, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Href, router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import PetRegisterForm from '@/src/components/onboarding/PetRegisterForm';
import AppText from '@/src/components/shared/AppText';
import { useAuth } from '@/src/lib/auth-context';
import { colors } from '@/src/lib/colors';
import { usePets } from '@/src/lib/pet-context';
import { getSpeciesEmoji, SPECIES_LIST } from '@/src/lib/record-types';
import { Pet } from '@/src/types';

type IconName = ComponentProps<typeof Ionicons>['name'];

const managementMenus: MenuItem[] = [
  { label: '예방접종 스케줄', icon: 'medical-outline', route: { pathname: '/my/[section]', params: { section: 'vaccinations' } } },
  { label: '투약 기록', icon: 'bandage-outline', route: { pathname: '/my/[section]', params: { section: 'medicine' } } },
  { label: '체중 변화 그래프', icon: 'analytics-outline', route: '/growth' },
  { label: '내가 쓴 게시글', icon: 'document-text-outline', route: { pathname: '/my/[section]', params: { section: 'posts' } } },
  { label: '북마크한 건강 꿀팁', icon: 'bookmark-outline', route: { pathname: '/my/[section]', params: { section: 'bookmarks' } } },
];

const supportMenus: MenuItem[] = [
  { label: '공지사항', icon: 'megaphone-outline', route: { pathname: '/my/[section]', params: { section: 'notices' } } },
  { label: '문의하기', icon: 'chatbubble-ellipses-outline', route: { pathname: '/my/[section]', params: { section: 'contact' } } },
];

interface MenuItem {
  label: string;
  icon: IconName;
  route: Href;
}

function speciesLabelOf(pet: Pet) {
  return SPECIES_LIST.find((species) => species.id === pet.species)?.label ?? pet.species;
}

function ProfileAvatar({ uri, size = 54 }: { uri?: string | null; size?: number }) {
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: colors.surfaceSoft,
        borderWidth: 1,
        borderColor: colors.border,
        alignItems: 'center',
        justifyContent: 'center',
        overflow: 'hidden',
      }}
    >
      {uri ? (
        <Image source={{ uri }} style={{ width: size, height: size }} />
      ) : (
        <Ionicons name="person" size={Math.round(size * 0.45)} color={colors.primaryPressed} />
      )}
    </View>
  );
}

function PetRailCard({ pet }: { pet: Pet }) {
  return (
    <Pressable
      onPress={() => router.push(`/pet/${pet.id}`)}
      style={{
        width: 148,
        minHeight: 140,
        backgroundColor: colors.surface,
        borderRadius: 20,
        borderWidth: 1,
        borderColor: colors.border,
        padding: 14,
        marginRight: 10,
      }}
    >
      <View
        style={{
          width: 54,
          height: 54,
          borderRadius: 27,
          backgroundColor: pet.bgLight || colors.surfaceSoft,
          borderWidth: 1,
          borderColor: pet.accentColor || colors.border,
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: 12,
        }}
      >
        <AppText style={{ fontSize: 28 }}>{getSpeciesEmoji(pet.species)}</AppText>
      </View>
      <AppText bold numberOfLines={1} style={{ fontSize: 16, color: colors.text }}>
        {pet.name}
      </AppText>
      <AppText numberOfLines={2} style={{ fontSize: 12, color: colors.textSecondary, marginTop: 3, lineHeight: 18 }}>
        {speciesLabelOf(pet)}
        {pet.gender === 'male' ? ' · 남아' : pet.gender === 'female' ? ' · 여아' : ''}
      </AppText>
    </Pressable>
  );
}

function AddPetCard({ onPress }: { onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={{
        width: 148,
        minHeight: 140,
        backgroundColor: colors.surfaceSoft,
        borderRadius: 20,
        borderWidth: 1.5,
        borderColor: colors.border,
        borderStyle: 'dashed',
        padding: 14,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <View
        style={{
          width: 54,
          height: 54,
          borderRadius: 27,
          backgroundColor: colors.surface,
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: 10,
        }}
      >
        <Ionicons name="add" size={28} color={colors.primary} />
      </View>
      <AppText bold style={{ fontSize: 14, color: colors.text }}>
        아이 추가
      </AppText>
    </Pressable>
  );
}

function ManagementSection({ items }: { items: MenuItem[] }) {
  return (
    <View
      style={{
        marginTop: 22,
        backgroundColor: colors.surface,
        borderRadius: 22,
        borderWidth: 1,
        borderColor: colors.border,
        padding: 16,
      }}
    >
      <AppText bold style={{ fontSize: 15, color: colors.text, marginBottom: 12 }}>
        관리
      </AppText>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
        {items.map((item) => (
          <Pressable
            key={item.label}
            onPress={() => router.push(item.route)}
            style={{
              width: '31%',
              flexBasis: '31%',
              minHeight: 112,
              backgroundColor: colors.surfaceSoft,
              borderRadius: 16,
              borderWidth: 1,
              borderColor: colors.border,
              paddingVertical: 15,
              paddingHorizontal: 8,
              alignItems: 'center',
            }}
          >
            <View
              style={{
                width: 46,
                height: 46,
                borderRadius: 23,
                backgroundColor: colors.surface,
                alignItems: 'center',
                justifyContent: 'center',
                marginBottom: 9,
              }}
            >
              <Ionicons name={item.icon} size={22} color={colors.primaryPressed} />
            </View>
            <AppText bold numberOfLines={2} style={{ fontSize: 12, color: colors.text, textAlign: 'center', lineHeight: 17 }}>
              {item.label}
            </AppText>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

function SupportList({ items }: { items: MenuItem[] }) {
  return (
    <View
      style={{
        marginTop: 22,
        backgroundColor: colors.surface,
        borderRadius: 20,
        borderWidth: 1,
        borderColor: colors.border,
        overflow: 'hidden',
      }}
    >
      {items.map((item, index) => (
        <Pressable
          key={item.label}
          onPress={() => router.push(item.route)}
          style={{
            minHeight: 54,
            paddingHorizontal: 16,
            flexDirection: 'row',
            alignItems: 'center',
            borderTopWidth: index === 0 ? 0 : 1,
            borderTopColor: colors.border,
          }}
        >
          <Ionicons name={item.icon} size={20} color={colors.textSecondary} />
          <AppText style={{ flex: 1, fontSize: 14, color: colors.text, marginLeft: 12 }}>
            {item.label}
          </AppText>
          <Ionicons name="chevron-forward" size={18} color={colors.muted} />
        </Pressable>
      ))}
    </View>
  );
}

export default function MyScreen() {
  const { pets } = usePets();
  const { logout, profile } = useAuth();
  const [showAddForm, setShowAddForm] = useState(false);

  async function handleLogout() {
    await logout();
    router.replace('/auth');
  }

  if (showAddForm) {
    return (
      <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: colors.background }}>
        <Pressable
          onPress={() => setShowAddForm(false)}
          style={{ paddingHorizontal: 20, paddingTop: 12, paddingBottom: 4, flexDirection: 'row', alignItems: 'center', gap: 4 }}
        >
          <Ionicons name="chevron-back" size={20} color={colors.primaryPressed} />
          <AppText bold style={{ fontSize: 14, color: colors.primaryPressed }}>
            돌아가기
          </AppText>
        </Pressable>
        <PetRegisterForm onComplete={() => setShowAddForm(false)} skipOnboarding />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: colors.background }}>
      <View
        style={{
          paddingHorizontal: 20,
          paddingTop: 8,
          paddingBottom: 12,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 12,
        }}
      >
        <Pressable
          onPress={() => router.push('/my/profile')}
          style={{ maxWidth: '82%', minWidth: 0, flexShrink: 1, flexDirection: 'row', alignItems: 'center', gap: 12 }}
        >
          <ProfileAvatar uri={profile?.profileImageUrl} />
          <AppText bold numberOfLines={1} style={{ flexShrink: 1, minWidth: 0, fontSize: 18, color: colors.text }}>
            {profile?.nickname ?? '사용자'}
          </AppText>
          <Ionicons name="chevron-forward" size={20} color={colors.muted} />
        </Pressable>
        <View style={{ flex: 1 }} />
        <Pressable
          onPress={() => router.push({ pathname: '/my/[section]', params: { section: 'notifications' } })}
          style={{
            width: 44,
            height: 44,
            borderRadius: 22,
            backgroundColor: colors.surface,
            borderWidth: 1,
            borderColor: colors.border,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Ionicons name="notifications-outline" size={21} color={colors.text} />
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={{ paddingBottom: 36 }} showsVerticalScrollIndicator={false}>
        <View style={{ paddingLeft: 20, marginTop: 4 }}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingRight: 20 }}>
            {pets.map((pet) => (
              <PetRailCard key={pet.id} pet={pet} />
            ))}
            <AddPetCard onPress={() => setShowAddForm(true)} />
          </ScrollView>
        </View>

        <View style={{ paddingHorizontal: 20 }}>
          <ManagementSection items={managementMenus} />
          <SupportList items={supportMenus} />

          <Pressable
            onPress={handleLogout}
            style={{
              marginTop: 18,
              minHeight: 52,
              borderRadius: 18,
              borderWidth: 1,
              borderColor: colors.border,
              backgroundColor: colors.surfaceSoft,
              alignItems: 'center',
              justifyContent: 'center',
              flexDirection: 'row',
              gap: 8,
            }}
          >
            <Ionicons name="log-out-outline" size={20} color={colors.textSecondary} />
            <AppText bold style={{ fontSize: 14, color: colors.textSecondary }}>
              로그아웃
            </AppText>
          </Pressable>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
