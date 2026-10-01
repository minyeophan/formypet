import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/post.dart';

void main() {
  test('fromJson parses mediaUrls and poll options', () {
    final post = Post.fromJson({
      'id': 'post-1',
      'userId': 'user-1',
      'authorNickname': 'Momo',
      'content': 'hello',
      'category': 'CARE',
      'likesCount': 3,
      'liked': true,
      'commentsCount': 2,
      'mediaUrls': ['/media/1.png', '/media/2.png'],
      'createdAt': '2026-05-21T12:00:00',
      'poll': {
        'id': 'poll-1',
        'question': 'Best snack?',
        'options': [
          {
            'id': 'option-1',
            'text': 'Apple',
            'votesCount': 5,
            'votedByMe': true,
          },
          {
            'id': 'option-2',
            'text': 'Berry',
            'votesCount': 1,
            'votedByMe': false,
          },
        ],
      },
    });

    expect(post.imageUrls, ['/media/1.png', '/media/2.png']);
    expect(post.poll?.id, 'poll-1');
    expect(post.poll?.question, 'Best snack?');
    expect(post.poll?.options.first.votesCount, 5);
    expect(post.poll?.options.first.votedByMe, isTrue);
  });

  test('copyWith preserves or replaces poll state', () {
    const originalPoll = PostPoll(
      id: 'poll-1',
      question: 'Which walk time?',
      options: [
        PostPollOption(
          id: 'morning',
          text: 'Morning',
          votesCount: 2,
          votedByMe: false,
        ),
      ],
    );
    const replacementPoll = PostPoll(
      id: 'poll-1',
      question: 'Which walk time?',
      options: [
        PostPollOption(
          id: 'morning',
          text: 'Morning',
          votesCount: 3,
          votedByMe: true,
        ),
      ],
    );
    const post = Post(
      id: 'post-1',
      userId: 'user-1',
      authorNickname: 'Momo',
      content: 'hello',
      category: 'FREE',
      likesCount: 0,
      liked: false,
      commentsCount: 0,
      imageUrls: [],
      poll: originalPoll,
      createdAt: '2026-06-23T00:00:00',
    );

    expect(post.copyWith(liked: true).poll, same(originalPoll));
    expect(post.copyWith(poll: replacementPoll).poll, same(replacementPoll));
    expect(
      originalPoll.copyWith(options: replacementPoll.options).options,
      same(replacementPoll.options),
    );
    final updatedOption = originalPoll.options.single.copyWith(
      votesCount: 3,
      votedByMe: true,
    );
    expect(updatedOption.votesCount, 3);
    expect(updatedOption.votedByMe, isTrue);
  });

  test('parses server poll option label and replaces comments count', () {
    final post = Post.fromJson({
      'id': 1,
      'userId': 2,
      'authorNickname': 'Momo',
      'content': '내용',
      'category': 'QUESTION',
      'likesCount': 0,
      'liked': false,
      'commentsCount': 1,
      'mediaUrls': [],
      'poll': {
        'id': 3,
        'question': '언제 갈까요?',
        'options': [
          {'id': 4, 'label': '오전', 'votesCount': 0, 'votedByMe': false},
        ],
      },
      'createdAt': '2026-06-24T00:00:00',
    });

    expect(post.poll?.options.single.text, '오전');
    expect(post.copyWith(commentsCount: 2).commentsCount, 2);
  });

  test('PostComment.fromJson parses author profile image url', () {
    final comment = PostComment.fromJson({
      'id': 9,
      'userId': 1,
      'authorNickname': 'Momo',
      'authorProfileImageUrl': '/api/v1/users/1/profile-image',
      'content': 'hello',
      'createdAt': '2026-06-24T00:00:00',
      'commentsCount': 2,
    });

    expect(comment.authorProfileImageUrl, '/api/v1/users/1/profile-image');
  });

  test('PostComment.fromJson parses deleted tombstone safely', () {
    final comment = PostComment.fromJson({
      'id': 9,
      'userId': null,
      'authorNickname': null,
      'authorProfileImageUrl': null,
      'content': null,
      'createdAt': '2026-07-08T00:00:00',
      'updatedAt': '2026-07-08T01:00:00',
      'deleted': true,
      'commentsCount': 1,
    });

    expect(comment.userId, '');
    expect(comment.authorNickname, '');
    expect(comment.content, '');
    expect(comment.updatedAt, '2026-07-08T01:00:00');
    expect(comment.deleted, isTrue);
    expect(comment.copyWith().deleted, isTrue);
  });
}
