import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post.dart';
import 'community_mock_data.dart';

class MockCommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorNickname;
  final String content;
  final String createdAt;

  const MockCommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorNickname,
    required this.content,
    required this.createdAt,
  });
}

class MockCommunityState {
  final List<Post> posts;
  final Map<String, List<MockCommunityComment>> commentsByPostId;

  const MockCommunityState({
    required this.posts,
    required this.commentsByPostId,
  });

  Post? postById(String postId) {
    for (final post in posts) {
      if (post.id == postId) return post;
    }
    return null;
  }

  List<MockCommunityComment> commentsFor(String postId) =>
      commentsByPostId[postId] ?? const [];

  int commentsCountFor(String postId) {
    final visibleCount = commentsFor(postId).length;
    final serverCount = postById(postId)?.commentsCount ?? 0;
    return serverCount > visibleCount ? serverCount : visibleCount;
  }

  MockCommunityState copyWith({
    List<Post>? posts,
    Map<String, List<MockCommunityComment>>? commentsByPostId,
  }) => MockCommunityState(
    posts: posts ?? this.posts,
    commentsByPostId: commentsByPostId ?? this.commentsByPostId,
  );
}

class MockCommunityNotifier extends StateNotifier<MockCommunityState> {
  static const currentUserId = 'mock-me';

  MockCommunityNotifier()
    : super(
        const MockCommunityState(
          posts: mockCommunityPosts,
          commentsByPostId: {
            'story-1': [
              MockCommunityComment(
                id: 'comment-story-1-best',
                postId: 'story-1',
                authorId: 'mock-mami-9',
                authorNickname: '익명마미9',
                content: '''
쓰니가 결혼할 때 축의 받았어?
그럼 축의만 하고 자연스럽게 끝내면 될 듯.
나도 저런 타입은 손절하는 편이야.''',
                createdAt: '17분 전',
              ),
              MockCommunityComment(
                id: 'comment-story-1-2',
                postId: 'story-1',
                authorId: 'mock-mami-16',
                authorNickname: '익명마미16',
                content: '''
22
어차피 말해도 몰라.
알려줄 필요 없어.''',
                createdAt: '3분 전',
              ),
              MockCommunityComment(
                id: 'comment-story-1-3',
                postId: 'story-1',
                authorId: 'mock-mami-5',
                authorNickname: '익명마미5',
                content: '''
나도 비슷한 경험 있었는데
거리 두는 게 결국 마음 편하더라.''',
                createdAt: '방금 전',
              ),
            ],
            'photo-1': [
              MockCommunityComment(
                id: 'comment-photo-1-a',
                postId: 'photo-1',
                authorId: 'mock-sora',
                authorNickname: '소라',
                content: '사진이 정말 귀여워요!',
                createdAt: '2026-06-23T09:40:00',
              ),
              MockCommunityComment(
                id: 'comment-photo-1-b',
                postId: 'photo-1',
                authorId: 'mock-dal',
                authorNickname: '달',
                content: '즐거운 산책이었겠어요.',
                createdAt: '2026-06-23T09:45:00',
              ),
            ],
          },
        ),
      );

  void toggleLike(String postId) {
    state = state.copyWith(
      posts: [
        for (final post in state.posts)
          if (post.id == postId)
            post.copyWith(
              liked: !post.liked,
              likesCount: post.likesCount + (post.liked ? -1 : 1),
            )
          else
            post,
      ],
    );
  }

  void vote(String postId, String optionId) {
    final post = state.postById(postId);
    final poll = post?.poll;
    if (post == null ||
        poll == null ||
        !poll.options.any((option) => option.id == optionId)) {
      return;
    }

    String? previousOptionId;
    for (final option in poll.options) {
      if (option.votedByMe) {
        previousOptionId = option.id;
        break;
      }
    }
    if (previousOptionId == optionId) return;

    final updatedPoll = poll.copyWith(
      options: [
        for (final option in poll.options)
          if (option.id == optionId)
            option.copyWith(votesCount: option.votesCount + 1, votedByMe: true)
          else if (option.id == previousOptionId)
            option.copyWith(votesCount: option.votesCount - 1, votedByMe: false)
          else
            option.copyWith(votedByMe: false),
      ],
    );
    state = state.copyWith(
      posts: [
        for (final item in state.posts)
          item.id == postId ? item.copyWith(poll: updatedPoll) : item,
      ],
    );
  }

  void addComment(String postId, String rawContent) {
    final content = rawContent.trim();
    if (content.isEmpty || state.postById(postId) == null) return;

    final comments = Map<String, List<MockCommunityComment>>.from(
      state.commentsByPostId,
    );
    final existing = comments[postId] ?? const [];
    final newCount = state.commentsCountFor(postId) + 1;
    comments[postId] = [
      ...existing,
      MockCommunityComment(
        id: 'comment-$postId-${existing.length + 1}',
        postId: postId,
        authorId: currentUserId,
        authorNickname: '나',
        content: content,
        createdAt: '방금 전',
      ),
    ];
    state = state.copyWith(
      commentsByPostId: comments,
      posts: [
        for (final post in state.posts)
          post.id == postId ? post.copyWith(commentsCount: newCount) : post,
      ],
    );
  }
}

final mockCommunityProvider =
    StateNotifierProvider<MockCommunityNotifier, MockCommunityState>((ref) {
      return MockCommunityNotifier();
    });
