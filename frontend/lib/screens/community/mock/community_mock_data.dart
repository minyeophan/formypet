import '../../../models/post.dart';

const mockCommunityPosts = [
  Post(
    id: 'story-1',
    userId: 'mock-me',
    authorNickname: '익명마미',
    title: '오랜 친구 정리한 마미 있어? 도와줘',
    content: '''
학창시절 진짜 친하게 지낸, 말 그대로 절친이야.
다른 친구들도 다 이 친구의 이름을 알 정도였어.

근데 커가면서 조금씩 가치관이나 성향이 달라졌고,
본인 콤플렉스 때문에 자존감이 깎이는 건지
본인 관련된 건 아주 사소한 것도 장점으로 포장하고,
나는 은근히 깔보는 말투를 가끔씩 해서 불편했어.

연애할 때도 별로인 상대만 만나길래
진심으로 걱정하는 마음으로 이야기해줬는데,
내 말은 듣지 않고 결국 같은 문제로 헤어졌어.

그래서 나도 지쳐서 거리를 두게 됐고,
이제는 연락도 SNS도 하지 않고 있어.
''',
    category: '훈훈익명',
    likesCount: 1,
    liked: false,
    commentsCount: 22,
    imageUrls: [],
    createdAt: '2026-06-25T13:00:00',
  ),
  Post(
    id: 'photo-1',
    userId: 'mock-hana',
    authorNickname: '하나',
    title: '오늘 공원에서 만난 친구들',
    content: '날씨가 좋아서 오래 산책했어요. 모두 즐거운 하루 보내세요!',
    category: 'OUTING',
    likesCount: 12,
    liked: false,
    commentsCount: 0,
    imageUrls: ['mock://photo-1/a', 'mock://photo-1/b'],
    createdAt: '2026-06-23T09:30:00',
  ),
  Post(
    id: 'poll-1',
    userId: 'mock-jun',
    authorNickname: '준',
    title: '산책 시간, 언제가 좋을까요?',
    content: '이번 주말에 같이 산책할 시간을 골라 주세요.',
    category: 'QUESTION',
    likesCount: 4,
    liked: false,
    commentsCount: 0,
    imageUrls: [],
    poll: PostPoll(
      id: 'poll-1',
      question: '가장 좋은 산책 시간은?',
      options: [
        PostPollOption(
          id: 'poll-option-a',
          text: '오전 10시',
          votesCount: 0,
          votedByMe: false,
        ),
        PostPollOption(
          id: 'poll-option-b',
          text: '오후 4시',
          votesCount: 0,
          votedByMe: false,
        ),
      ],
    ),
    createdAt: '2026-06-23T08:10:00',
  ),
  Post(
    id: 'text-1',
    userId: 'mock-yuri',
    authorNickname: '유리',
    title: '간식 추천 부탁드려요',
    content: '알레르기 걱정이 적은 간식을 찾고 있어요.',
    category: 'FOOD',
    likesCount: 0,
    liked: false,
    commentsCount: 0,
    imageUrls: [],
    createdAt: '2026-06-22T18:20:00',
  ),
  Post(
    id: 'empty-comments-1',
    userId: 'mock-min',
    authorNickname: '민',
    title: '처음 올려 보는 근황',
    content: '우리 아이의 오늘 사진을 공유합니다.',
    category: 'SHOW',
    likesCount: 1,
    liked: false,
    commentsCount: 0,
    imageUrls: ['mock://empty-comments-1/a'],
    createdAt: '2026-06-22T12:00:00',
  ),
];
