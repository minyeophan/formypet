import { Pressable, View } from 'react-native';
import { Post } from '@/src/types';
import { getSpeciesEmoji } from '@/src/lib/record-types';
import { format, parseISO } from 'date-fns';
import { ko } from 'date-fns/locale';
import AppText from '../shared/AppText';

interface Props {
  post: Post;
  onLike: (id: string) => void;
}

export default function PostCard({ post, onLike }: Props) {
  const timeStr = format(parseISO(post.createdAt), 'M월 d일 HH:mm', { locale: ko });

  return (
    <View
      style={{
        backgroundColor: '#FFFFFF',
        borderRadius: 16,
        padding: 16,
        marginHorizontal: 20,
        marginBottom: 12,
      }}
    >
      {/* 작성자 */}
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 10 }}>
        <View
          style={{
            width: 36,
            height: 36,
            borderRadius: 18,
            backgroundColor: '#F5F3EF',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <AppText style={{ fontSize: 18 }}>{getSpeciesEmoji(post.petSpecies)}</AppText>
        </View>
        <View>
          <AppText bold style={{ fontSize: 14, color: '#1A1A1A' }}>{post.author}</AppText>
          <AppText style={{ fontSize: 11, color: '#B0A99F' }}>{timeStr}</AppText>
        </View>
      </View>

      {/* 내용 */}
      <AppText style={{ fontSize: 14, color: '#1A1A1A', lineHeight: 22, marginBottom: 12 }}>
        {post.content}
      </AppText>

      {/* 좋아요 */}
      <Pressable
        onPress={() => onLike(post.id)}
        style={{ flexDirection: 'row', alignItems: 'center', gap: 6, alignSelf: 'flex-start' }}
      >
        <AppText style={{ fontSize: 18 }}>{post.likedByMe ? '❤️' : '🤍'}</AppText>
        <AppText
          bold={post.likedByMe}
          style={{ fontSize: 13, color: post.likedByMe ? '#E57373' : '#B0A99F' }}
        >
          {post.likes}
        </AppText>
      </Pressable>
    </View>
  );
}
