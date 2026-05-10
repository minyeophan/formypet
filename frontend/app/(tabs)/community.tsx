import { useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Toast from 'react-native-toast-message';
import PostCard from '@/src/components/community/PostCard';
import { Post } from '@/src/types';
import AppText from '@/src/components/shared/AppText';
import { communityApi } from '@/src/services/api';

export default function CommunityScreen() {
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    communityApi.feed()
      .then((feed) => setPosts(feed.items))
      .catch((error) => Toast.show({ type: 'error', text1: error instanceof Error ? error.message : 'Feed load failed' }))
      .finally(() => setLoading(false));
  }, []);

  async function handleLike(id: string) {
    try {
      const updated = await communityApi.like(id);
      setPosts((prev) =>
        prev.map((p) => (p.id === updated.postId ? { ...p, likedByMe: updated.likedByMe, likes: updated.likes } : p)),
      );
      Toast.show({
        type: 'success',
        text1: updated.likedByMe ? 'Like saved.' : 'Like removed.',
        visibilityTime: 1500,
      });
    } catch (error) {
      Toast.show({ type: 'error', text1: error instanceof Error ? error.message : 'Like failed' });
    }
  }

  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: '#F5F3EF' }}>
      <View style={{ paddingHorizontal: 20, paddingTop: 8, paddingBottom: 12 }}>
        <AppText bold style={{ fontSize: 20, color: '#1A1A1A' }}>Community</AppText>
        <AppText style={{ fontSize: 13, color: '#B0A99F', marginTop: 2 }}>
          Stories from other pet families
        </AppText>
      </View>

      {loading ? (
        <View style={{ paddingTop: 40 }}>
          <ActivityIndicator />
        </View>
      ) : (
        <FlatList
          data={posts}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ paddingBottom: 24, paddingTop: 4 }}
          renderItem={({ item }) => <PostCard post={item} onLike={handleLike} />}
          showsVerticalScrollIndicator={false}
        />
      )}
    </SafeAreaView>
  );
}
