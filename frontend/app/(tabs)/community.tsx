import { useCallback, useRef, useState } from 'react';
import { ActivityIndicator, FlatList, Pressable, ScrollView, View } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { router, useFocusEffect } from 'expo-router';
import Toast from 'react-native-toast-message';
import PostCard from '@/src/components/community/PostCard';
import { Post } from '@/src/types';
import AppText from '@/src/components/shared/AppText';
import { communityApi } from '@/src/services/api';
import { colors } from '@/src/lib/colors';

type Board = {
  key: string;
  label: string;
  category?: string;
  sort: 'latest' | 'popular';
  icon: keyof typeof Ionicons.glyphMap;
  bg: string;
};

const BOARDS: Board[] = [
  { key: 'all', label: '전체', sort: 'latest', icon: 'apps-outline', bg: colors.surfaceSoft },
  { key: 'popular', label: '인기', sort: 'popular', icon: 'flame-outline', bg: '#FFF3E8' },
  { key: 'travel', label: '여행/나들이', category: 'TRAVEL', sort: 'latest', icon: 'map-outline', bg: '#F0F8FF' },
  { key: 'pet', label: '우리아이', category: 'PET', sort: 'latest', icon: 'paw-outline', bg: '#FFF8F0' },
  { key: 'training', label: '훈련', category: 'TRAINING', sort: 'latest', icon: 'school-outline', bg: '#F0FFF4' },
  { key: 'free', label: '자유', category: 'FREE', sort: 'latest', icon: 'chatbubble-ellipses-outline', bg: '#FFFBF0' },
  { key: 'event', label: '이벤트', category: 'EVENT', sort: 'latest', icon: 'sparkles-outline', bg: '#FFF0FF' },
  { key: 'food', label: '사료/간식', category: 'FOOD', sort: 'latest', icon: 'fast-food-outline', bg: '#FFF7E8' },
];

const BOARD_COLUMNS = Array.from({ length: Math.ceil(BOARDS.length / 2) }, (_, index) =>
  BOARDS.slice(index * 2, index * 2 + 2),
);

export default function CommunityScreen() {
  const insets = useSafeAreaInsets();
  const listRef = useRef<FlatList<Post>>(null);
  const [selected, setSelected] = useState(BOARDS[0]);
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(0);
  const [cursors, setCursors] = useState<Record<number, string | null>>({ 0: null });
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [showTop, setShowTop] = useState(false);

  const loadPage = useCallback(async (board: Board, pageIndex: number, cursorMap: Record<number, string | null>) => {
    setLoading(true);
    try {
      const feed = await communityApi.feed({
        category: board.category,
        sort: board.sort,
        cursor: cursorMap[pageIndex] ?? undefined,
        limit: 10,
      });
      setPosts(feed.items);
      setPage(pageIndex);
      setNextCursor(feed.nextCursor);
      setCursors((prev) => ({ ...prev, [pageIndex + 1]: feed.nextCursor }));
      listRef.current?.scrollToOffset({ offset: 0, animated: false });
    } catch (error) {
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : '게시글을 불러오지 못했어요' });
    } finally {
      setLoading(false);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      const reset = { 0: null };
      setCursors(reset);
      loadPage(selected, 0, reset);
    }, [loadPage, selected]),
  );

  function selectBoard(board: Board) {
    setSelected(board);
    const reset = { 0: null };
    setCursors(reset);
    loadPage(board, 0, reset);
  }

  async function handleLike(id: string) {
    try {
      const updated = await communityApi.like(id);
      setPosts((prev) =>
        prev.map((p) => (p.id === updated.postId ? { ...p, likedByMe: updated.likedByMe, likes: updated.likes } : p)),
      );
    } catch (error) {
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : '좋아요에 실패했어요' });
    }
  }

  async function handleVote(postId: string, optionId: string) {
    try {
      const updated = await communityApi.vote(postId, optionId);
      setPosts((prev) => prev.map((post) => (post.id === postId ? updated : post)));
    } catch (error) {
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : '투표에 실패했어요' });
    }
  }

  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: colors.background }}>
      <View style={{ paddingTop: 8, paddingBottom: 12 }}>
        <View style={{ paddingHorizontal: 20, marginBottom: 12 }}>
          <AppText bold style={{ fontSize: 19, color: colors.text }}>커뮤니티</AppText>
        </View>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={{ paddingHorizontal: 20, gap: 10 }}
        >
          {BOARD_COLUMNS.map((column) => (
            <View key={column.map((item) => item.key).join('-')} style={{ gap: 8 }}>
              {column.map((item) => {
                const active = item.key === selected.key;
                return (
                  <Pressable
                    key={item.key}
                    onPress={() => selectBoard(item)}
                    style={{
                      width: 92,
                      height: 74,
                      borderRadius: 20,
                      backgroundColor: active ? colors.surface : item.bg,
                      borderColor: active ? colors.primary : colors.border,
                      borderWidth: active ? 1.5 : 1,
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: 6,
                    }}
                  >
                    <View
                      style={{
                        width: 36,
                        height: 36,
                        borderRadius: 18,
                        backgroundColor: active ? colors.primary : colors.surface,
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <Ionicons
                        name={item.icon}
                        size={20}
                        color={active ? colors.white : colors.primaryPressed}
                      />
                    </View>
                    <AppText
                      bold={active}
                      numberOfLines={1}
                      style={{
                        width: 80,
                        textAlign: 'center',
                        fontSize: 11,
                        color: active ? colors.text : colors.textSecondary,
                      }}
                    >
                      {item.label}
                    </AppText>
                  </Pressable>
                );
              })}
            </View>
          ))}
        </ScrollView>
      </View>

      {loading ? (
        <View style={{ paddingTop: 40 }}>
          <ActivityIndicator />
        </View>
      ) : (
        <FlatList
          ref={listRef}
          data={posts}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ paddingBottom: insets.bottom + 118, paddingTop: 6 }}
          renderItem={({ item }) => <PostCard post={item} onLike={handleLike} onVote={handleVote} />}
          showsVerticalScrollIndicator={false}
          ListEmptyComponent={
            <View style={{ alignItems: 'center', paddingTop: 60, paddingHorizontal: 20 }}>
              <AppText style={{ fontSize: 28, marginBottom: 8 }}>🐾</AppText>
              <AppText bold style={{ fontSize: 14, color: colors.text }}>아직 게시글이 없어요</AppText>
            </View>
          }
          onScroll={(event) => setShowTop(event.nativeEvent.contentOffset.y > 280)}
          scrollEventThrottle={16}
          ListFooterComponent={
            posts.length > 0 ? (
              <View style={{ flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: 12, paddingVertical: 12 }}>
                <PageButton label="이전" disabled={page === 0} onPress={() => loadPage(selected, page - 1, cursors)} />
                <AppText bold style={{ fontSize: 13, color: colors.text }}>{page + 1}</AppText>
                <PageButton label="다음" disabled={!nextCursor} onPress={() => loadPage(selected, page + 1, cursors)} />
              </View>
            ) : null
          }
        />
      )}

      {showTop && (
        <Pressable
          onPress={() => listRef.current?.scrollToOffset({ offset: 0, animated: true })}
          style={{
            position: 'absolute',
            right: 24,
            bottom: insets.bottom + 88,
            width: 44,
            height: 44,
            borderRadius: 22,
            backgroundColor: colors.surface,
            borderColor: colors.border,
            borderWidth: 1,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Ionicons name="arrow-up" size={20} color={colors.primaryPressed} />
        </Pressable>
      )}
      <Pressable
        onPress={() => router.push('/community/write')}
        style={{
          position: 'absolute',
          right: 20,
          bottom: insets.bottom + 26,
          width: 52,
          height: 52,
          borderRadius: 26,
          backgroundColor: colors.primary,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Ionicons name="create-outline" size={24} color={colors.white} />
      </Pressable>
    </SafeAreaView>
  );
}

function PageButton({ label, disabled, onPress }: { label: string; disabled: boolean; onPress: () => void }) {
  return (
    <Pressable
      disabled={disabled}
      onPress={onPress}
      style={{
        minWidth: 54,
        height: 34,
        borderRadius: 17,
        backgroundColor: disabled ? colors.surfaceSoft : colors.surface,
        borderColor: colors.border,
        borderWidth: 1,
        alignItems: 'center',
        justifyContent: 'center',
        opacity: disabled ? 0.5 : 1,
      }}
    >
      <AppText bold style={{ fontSize: 12, color: colors.textSecondary }}>{label}</AppText>
    </Pressable>
  );
}
