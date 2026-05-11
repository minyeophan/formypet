import { Image, Pressable, View } from 'react-native';
import { Post } from '@/src/types';
import { getSpeciesEmoji } from '@/src/lib/record-types';
import { format, parseISO } from 'date-fns';
import { ko } from 'date-fns/locale';
import AppText from '../shared/AppText';
import { colors } from '@/src/lib/colors';

interface Props {
  post: Post;
  onLike: (id: string) => void;
  onVote: (postId: string, optionId: string) => void;
}

const CATEGORY_LABELS: Record<string, string> = {
  TRAVEL: '여행/나들이',
  PET: '우리아이',
  TRAINING: '훈련',
  FREE: '자유',
  EVENT: '이벤트',
  FOOD: '사료/간식',
};

export default function PostCard({ post, onLike, onVote }: Props) {
  const timeStr = format(parseISO(post.createdAt), 'M월 d일 HH:mm', { locale: ko });

  return (
    <View
      style={{
        backgroundColor: colors.surface,
        borderColor: colors.border,
        borderWidth: 1,
        borderRadius: 18,
        padding: 14,
        marginHorizontal: 20,
        marginBottom: 10,
      }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 10 }}>
        <View
          style={{
            width: 34,
            height: 34,
            borderRadius: 17,
            backgroundColor: colors.surfaceSoft,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <AppText style={{ fontSize: 17 }}>{getSpeciesEmoji(post.petSpecies)}</AppText>
        </View>
        <View style={{ flex: 1 }}>
          <AppText bold style={{ fontSize: 13, color: colors.text }}>{post.author}</AppText>
          <AppText style={{ fontSize: 11, color: colors.muted }}>{timeStr}</AppText>
        </View>
        <View style={{ backgroundColor: colors.surfaceSoft, borderRadius: 12, paddingHorizontal: 8, paddingVertical: 4 }}>
          <AppText bold style={{ fontSize: 11, color: colors.primaryPressed }}>
            {CATEGORY_LABELS[post.category] ?? post.category}
          </AppText>
        </View>
      </View>

      <AppText bold style={{ fontSize: 15, color: colors.text, marginBottom: 6 }}>
        {post.title}
      </AppText>
      <AppText style={{ fontSize: 13, color: colors.text, lineHeight: 21, marginBottom: 10 }}>
        {post.content}
      </AppText>

      {post.mediaUrls.length > 0 && (
        <View style={{ flexDirection: 'row', gap: 6, marginBottom: 10 }}>
          {post.mediaUrls.slice(0, 3).map((url) => (
            <Image
              key={url}
              source={{ uri: url }}
              style={{ flex: 1, height: 88, borderRadius: 12, backgroundColor: colors.surfaceSoft }}
            />
          ))}
        </View>
      )}

      {post.poll && (
        <View style={{ backgroundColor: colors.surfaceSoft, borderRadius: 14, padding: 10, marginBottom: 10 }}>
          <AppText bold style={{ fontSize: 13, color: colors.text, marginBottom: 8 }}>
            {post.poll.question}
          </AppText>
          {post.poll.options.map((option) => (
            <Pressable
              key={option.id}
              onPress={() => onVote(post.id, option.id)}
              style={{
                minHeight: 36,
                borderRadius: 12,
                paddingHorizontal: 10,
                marginBottom: 6,
                backgroundColor: option.votedByMe ? colors.primary : colors.surface,
                borderColor: option.votedByMe ? colors.primary : colors.border,
                borderWidth: 1,
                flexDirection: 'row',
                alignItems: 'center',
                justifyContent: 'space-between',
              }}
            >
              <AppText bold={option.votedByMe} style={{ fontSize: 12, color: option.votedByMe ? colors.white : colors.text }}>
                {option.label}
              </AppText>
              <AppText bold={option.votedByMe} style={{ fontSize: 12, color: option.votedByMe ? colors.white : colors.muted }}>
                {option.votesCount}
              </AppText>
            </Pressable>
          ))}
        </View>
      )}

      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14 }}>
        <Pressable
          onPress={() => onLike(post.id)}
          style={{ flexDirection: 'row', alignItems: 'center', gap: 5, minHeight: 32 }}
        >
          <AppText style={{ fontSize: 17 }}>{post.likedByMe ? '❤️' : '🤍'}</AppText>
          <AppText bold={post.likedByMe} style={{ fontSize: 12, color: post.likedByMe ? '#E57373' : colors.muted }}>
            {post.likes}
          </AppText>
        </Pressable>
        <AppText style={{ fontSize: 12, color: colors.muted }}>댓글 {post.commentsCount}</AppText>
      </View>
    </View>
  );
}
