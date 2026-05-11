import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { Alert, Image, Pressable, ScrollView, TextInput, View } from 'react-native';
import Toast from 'react-native-toast-message';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import AppText from '@/src/components/shared/AppText';
import { colors } from '@/src/lib/colors';
import { useAuth } from '@/src/lib/auth-context';
import { usePets } from '@/src/lib/pet-context';

function SummaryTile({ label, value }: { label: string; value: number }) {
  return (
    <View
      style={{
        flex: 1,
        minWidth: 88,
        backgroundColor: colors.surfaceSoft,
        borderRadius: 16,
        borderWidth: 1,
        borderColor: colors.border,
        paddingVertical: 12,
        paddingHorizontal: 8,
        alignItems: 'center',
      }}
    >
      <AppText bold style={{ fontSize: 17, color: colors.text }}>
        {value}
      </AppText>
      <AppText numberOfLines={1} style={{ fontSize: 11, color: colors.textSecondary, marginTop: 2 }}>
        {label}
      </AppText>
    </View>
  );
}

export default function ProfileScreen() {
  const insets = useSafeAreaInsets();
  const { profile, updateProfile, uploadProfileImage } = useAuth();
  const { pets, records, routines } = usePets();
  const [nickname, setNickname] = useState(profile?.nickname ?? '');
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);

  useEffect(() => {
    setNickname(profile?.nickname ?? '');
  }, [profile?.nickname]);

  async function handleSave() {
    const trimmed = nickname.trim();
    if (!trimmed) {
      Toast.show({ type: 'error', text1: '이름을 입력해 주세요' });
      return;
    }
    setSaving(true);
    try {
      await updateProfile(trimmed);
      Toast.show({ type: 'success', text1: '내정보가 저장됐어요' });
    } catch (error) {
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : '저장에 실패했어요' });
    } finally {
      setSaving(false);
    }
  }

  async function handlePickImage() {
    const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (status !== 'granted') {
      Alert.alert('사진 접근 권한', '설정에서 사진 접근을 허용해 주세요.');
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      quality: 0.8,
    });
    if (result.canceled || !result.assets[0]) return;

    setUploading(true);
    try {
      await uploadProfileImage(result.assets[0].uri);
      Toast.show({ type: 'success', text1: '프로필사진이 바뀌었어요' });
    } catch (error) {
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : '업로드에 실패했어요' });
    } finally {
      setUploading(false);
    }
  }

  return (
    <View style={{ flex: 1, backgroundColor: colors.background, paddingTop: insets.top }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 12 }}>
        <Pressable onPress={() => router.back()} style={{ width: 40, height: 40, justifyContent: 'center' }}>
          <Ionicons name="chevron-back" size={26} color={colors.text} />
        </Pressable>
        <AppText bold style={{ flex: 1, fontSize: 18, color: colors.text, textAlign: 'center' }}>
          내정보
        </AppText>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 36 }} showsVerticalScrollIndicator={false}>
        <View
          style={{
            backgroundColor: colors.surface,
            borderRadius: 22,
            borderWidth: 1,
            borderColor: colors.border,
            padding: 18,
          }}
        >
          <Pressable onPress={handlePickImage} disabled={uploading} style={{ alignItems: 'center', marginBottom: 18 }}>
            <View
              style={{
                width: 92,
                height: 92,
                borderRadius: 46,
                backgroundColor: colors.surfaceSoft,
                borderWidth: 1,
                borderColor: colors.border,
                alignItems: 'center',
                justifyContent: 'center',
                overflow: 'hidden',
              }}
            >
              {profile?.profileImageUrl ? (
                <Image source={{ uri: profile.profileImageUrl }} style={{ width: 92, height: 92 }} />
              ) : (
                <Ionicons name="person" size={38} color={colors.primaryPressed} />
              )}
            </View>
            <View
              style={{
                marginTop: -28,
                marginLeft: 62,
                width: 34,
                height: 34,
                borderRadius: 17,
                backgroundColor: colors.primary,
                borderWidth: 2,
                borderColor: colors.surface,
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Ionicons name="camera-outline" size={17} color="#FFFFFF" />
            </View>
          </Pressable>

          <AppText bold style={{ fontSize: 13, color: colors.text, marginBottom: 7 }}>
            이름
          </AppText>
          <TextInput
            value={nickname}
            onChangeText={setNickname}
            maxLength={50}
            placeholder="이름을 입력해 주세요"
            placeholderTextColor={colors.muted}
            style={{
              minHeight: 48,
              borderRadius: 16,
              borderWidth: 1,
              borderColor: colors.border,
              backgroundColor: colors.surfaceSoft,
              paddingHorizontal: 14,
              fontFamily: 'NotoSansKR_400Regular',
              fontSize: 15,
              color: colors.text,
            }}
          />

          <View style={{ marginTop: 16 }}>
            <AppText bold style={{ fontSize: 13, color: colors.text, marginBottom: 7 }}>
              아이디
            </AppText>
            <View
              style={{
                minHeight: 48,
                borderRadius: 16,
                borderWidth: 1,
                borderColor: colors.border,
                backgroundColor: colors.surfaceSoft,
                paddingHorizontal: 14,
                justifyContent: 'center',
              }}
            >
              <AppText numberOfLines={1} style={{ fontSize: 14, color: colors.textSecondary }}>
                {profile?.email ?? '-'}
              </AppText>
            </View>
          </View>

          <View style={{ flexDirection: 'row', gap: 8, marginTop: 18 }}>
            <SummaryTile label="관리 펫" value={pets.length} />
            <SummaryTile label="누적 기록" value={records.length} />
            <SummaryTile label="등록 루틴" value={routines.length} />
          </View>
        </View>

        <Pressable
          onPress={handleSave}
          disabled={saving}
          style={{
            marginTop: 16,
            minHeight: 52,
            borderRadius: 18,
            backgroundColor: saving ? colors.muted : colors.primary,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <AppText bold style={{ fontSize: 15, color: '#FFFFFF' }}>
            저장하기
          </AppText>
        </Pressable>
      </ScrollView>
    </View>
  );
}
