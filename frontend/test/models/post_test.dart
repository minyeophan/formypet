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
}
