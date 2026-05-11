import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Image, Pressable, ScrollView, TextInput, View } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import Toast from 'react-native-toast-message';
import AppText from '@/src/components/shared/AppText';
import { colors } from '@/src/lib/colors';
import { communityApi } from '@/src/services/api';
import { UnsupportedUploadFileTypeError, createUploadFilePart, UploadAsset } from '@/src/services/upload-file-part';

const CATEGORIES = [
  { label: '여행/나들이', value: 'TRAVEL' },
  { label: '우리아이', value: 'PET' },
  { label: '훈련', value: 'TRAINING' },
  { label: '자유', value: 'FREE' },
  { label: '이벤트', value: 'EVENT' },
  { label: '사료/간식', value: 'FOOD' },
];

export default function CommunityWriteScreen() {
  const insets = useSafeAreaInsets();
  const [category, setCategory] = useState('FREE');
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [photos, setPhotos] = useState<UploadAsset[]>([]);
  const [pollEnabled, setPollEnabled] = useState(false);
  const [pollQuestion, setPollQuestion] = useState('');
  const [pollOptions, setPollOptions] = useState(['', '']);
  const [submitting, setSubmitting] = useState(false);

  async function pickPhoto() {
    if (photos.length >= 3) {
      Toast.show({ type: 'info', text1: '사진은 최대 3장까지 첨부할 수 있어요' });
      return;
    }
    const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (status !== 'granted') {
      Toast.show({ type: 'error', text1: '사진 접근 권한이 필요해요' });
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      quality: 0.85,
      allowsMultipleSelection: true,
      selectionLimit: 3 - photos.length,
    });
    if (result.canceled) return;

    try {
      const picked = result.assets.map((asset) => ({
        uri: asset.uri,
        fileName: asset.fileName,
        mimeType: asset.mimeType,
      }));
      picked.forEach(createUploadFilePart);
      setPhotos((prev) => [...prev, ...picked].slice(0, 3));
    } catch (error) {
      Toast.show({
        type: 'error',
        text1: error instanceof UnsupportedUploadFileTypeError ? error.message : '첨부할 수 없는 이미지예요',
      });
    }
  }

  async function submit() {
    const trimmedTitle = title.trim();
    const trimmedContent = content.trim();
    if (!trimmedTitle || !trimmedContent) {
      Toast.show({ type: 'error', text1: '제목과 본문을 입력해 주세요' });
      return;
    }

    const poll = pollEnabled ? {
      question: pollQuestion.trim(),
      options: pollOptions.map((option) => option.trim()).filter(Boolean),
    } : null;
    if (pollEnabled && (!poll?.question || poll.options.length < 2)) {
      Toast.show({ type: 'error', text1: '투표 질문과 선택지 2개 이상을 입력해 주세요' });
      return;
    }

    setSubmitting(true);
    try {
      await communityApi.create({
        title: trimmedTitle,
        category,
        content: trimmedContent,
        poll,
      }, photos);
      Toast.show({ type: 'success', text1: '게시글이 등록됐어요' });
      router.back();
    } catch (error) {
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : '등록에 실패했어요' });
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <SafeAreaView edges={['top', 'bottom']} style={{ flex: 1, backgroundColor: colors.background }}>
      <View
        style={{
          height: 54,
          paddingHorizontal: 16,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'space-between',
          borderBottomColor: colors.border,
          borderBottomWidth: 1,
        }}
      >
        <Pressable onPress={() => router.back()} style={{ minWidth: 54, minHeight: 44, justifyContent: 'center' }}>
          <AppText bold style={{ fontSize: 14, color: colors.textSecondary }}>취소</AppText>
        </Pressable>
        <AppText bold style={{ fontSize: 15, color: colors.text }}>
          {CATEGORIES.find((item) => item.value === category)?.label}
        </AppText>
        <Pressable
          disabled={submitting}
          onPress={submit}
          style={{
            minWidth: 54,
            minHeight: 36,
            borderRadius: 14,
            backgroundColor: submitting ? colors.muted : colors.primary,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <AppText bold style={{ fontSize: 13, color: colors.white }}>등록</AppText>
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: insets.bottom + 96 }} keyboardShouldPersistTaps="handled">
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8, marginBottom: 14 }}>
          {CATEGORIES.map((item) => {
            const active = item.value === category;
            return (
              <Pressable
                key={item.value}
                onPress={() => setCategory(item.value)}
                style={{
                  height: 36,
                  paddingHorizontal: 12,
                  borderRadius: 18,
                  backgroundColor: active ? colors.primary : colors.surface,
                  borderColor: active ? colors.primary : colors.border,
                  borderWidth: 1,
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <AppText bold={active} style={{ fontSize: 12, color: active ? colors.white : colors.textSecondary }}>
                  {item.label}
                </AppText>
              </Pressable>
            );
          })}
        </ScrollView>

        <TextInput
          value={title}
          onChangeText={setTitle}
          placeholder="제목"
          maxLength={120}
          style={{
            minHeight: 48,
            borderBottomWidth: 1,
            borderBottomColor: colors.border,
            color: colors.text,
            fontSize: 18,
            fontFamily: 'NotoSansKR_700Bold',
            paddingVertical: 8,
          }}
          placeholderTextColor={colors.muted}
        />
        <TextInput
          value={content}
          onChangeText={setContent}
          placeholder="내용을 입력해 주세요"
          multiline
          textAlignVertical="top"
          style={{
            minHeight: 220,
            color: colors.text,
            fontSize: 14,
            lineHeight: 22,
            fontFamily: 'NotoSansKR_400Regular',
            paddingTop: 16,
          }}
          placeholderTextColor={colors.muted}
        />

        {photos.length > 0 && (
          <View style={{ flexDirection: 'row', gap: 8, marginTop: 8 }}>
            {photos.map((photo, index) => (
              <View key={`${photo.uri}-${index}`} style={{ flex: 1 }}>
                <Image source={{ uri: photo.uri }} style={{ height: 88, borderRadius: 14, backgroundColor: colors.surfaceSoft }} />
                <Pressable
                  onPress={() => setPhotos((prev) => prev.filter((_, photoIndex) => photoIndex !== index))}
                  style={{
                    position: 'absolute',
                    right: 6,
                    top: 6,
                    width: 24,
                    height: 24,
                    borderRadius: 12,
                    backgroundColor: 'rgba(28,28,28,0.55)',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <Ionicons name="close" size={15} color={colors.white} />
                </Pressable>
              </View>
            ))}
          </View>
        )}

        {pollEnabled && (
          <View style={{ backgroundColor: colors.surfaceSoft, borderRadius: 16, padding: 12, marginTop: 16 }}>
            <TextInput
              value={pollQuestion}
              onChangeText={setPollQuestion}
              placeholder="투표 질문"
              style={{
                minHeight: 40,
                color: colors.text,
                fontSize: 14,
                fontFamily: 'NotoSansKR_700Bold',
                borderBottomWidth: 1,
                borderBottomColor: colors.border,
                marginBottom: 8,
              }}
              placeholderTextColor={colors.muted}
            />
            {pollOptions.map((option, index) => (
              <View key={index} style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                <TextInput
                  value={option}
                  onChangeText={(text) => setPollOptions((prev) => prev.map((item, optionIndex) => optionIndex === index ? text : item))}
                  placeholder={`선택지 ${index + 1}`}
                  style={{
                    flex: 1,
                    minHeight: 40,
                    borderRadius: 12,
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                    borderWidth: 1,
                    paddingHorizontal: 10,
                    color: colors.text,
                    fontFamily: 'NotoSansKR_400Regular',
                  }}
                  placeholderTextColor={colors.muted}
                />
                {pollOptions.length > 2 && (
                  <Pressable onPress={() => setPollOptions((prev) => prev.filter((_, optionIndex) => optionIndex !== index))}>
                    <Ionicons name="remove-circle-outline" size={22} color={colors.muted} />
                  </Pressable>
                )}
              </View>
            ))}
            {pollOptions.length < 5 && (
              <Pressable onPress={() => setPollOptions((prev) => [...prev, ''])} style={{ alignSelf: 'flex-start', minHeight: 36, justifyContent: 'center' }}>
                <AppText bold style={{ fontSize: 12, color: colors.primaryPressed }}>선택지 추가</AppText>
              </Pressable>
            )}
          </View>
        )}
      </ScrollView>

      <View
        style={{
          position: 'absolute',
          right: 20,
          bottom: insets.bottom + 18,
          flexDirection: 'row',
          gap: 10,
        }}
      >
        <ToolButton icon="image-outline" onPress={pickPhoto} />
        <ToolButton icon="stats-chart-outline" active={pollEnabled} onPress={() => setPollEnabled((value) => !value)} />
      </View>
    </SafeAreaView>
  );
}

function ToolButton({ icon, active, onPress }: { icon: keyof typeof Ionicons.glyphMap; active?: boolean; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={{
        width: 48,
        height: 48,
        borderRadius: 24,
        backgroundColor: active ? colors.primaryPressed : colors.primary,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Ionicons name={icon} size={22} color={colors.white} />
    </Pressable>
  );
}
