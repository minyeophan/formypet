class MyNotice {
  final String id;
  final String title;
  final String date;
  final String body;

  const MyNotice({
    required this.id,
    required this.title,
    required this.date,
    required this.body,
  });
}

class MyFaqCategory {
  final String id;
  final String title;
  final String lead;

  const MyFaqCategory({
    required this.id,
    required this.title,
    required this.lead,
  });
}

class MyFaq {
  final String id;
  final String categoryId;
  final String title;
  final String body;

  const MyFaq({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.body,
  });
}

// Add only confirmed announcements; sample schedules must not appear in the app.
const myNotices = <MyNotice>[];

const myFaqCategories = [
  MyFaqCategory(
    id: 'account',
    title: '계정 관련',
    lead: '계정, 로그인, 공동집사, 약관 확인과 관련된 질문을 모았습니다.',
  ),
  MyFaqCategory(
    id: 'records',
    title: '기록 관련',
    lead: '반려동물 기록 작성, 날짜, 사진 첨부와 관련된 질문을 모았습니다.',
  ),
  MyFaqCategory(
    id: 'routine',
    title: '루틴 관련',
    lead: '루틴 반복, 완료 체크, 일정 저장과 관련된 질문을 모았습니다.',
  ),
  MyFaqCategory(
    id: 'community',
    title: '커뮤니티 관련',
    lead: '게시글, 이미지, 투표, 나의 활동과 관련된 질문을 모았습니다.',
  ),
];

const myFaqs = [
  MyFaq(
    id: 'account-email',
    categoryId: 'account',
    title: '로그인한 이메일을 변경할 수 있나요?',
    body:
        '로그인 이메일은 계정 식별에 사용하며, 앱에서 직접 변경할 수 없어요.\n\n1대1 문의의 답변받을 이메일은 별도로 입력할 수 있어요. 문의 이메일을 바꿔도 로그인 이메일은 변경되지 않아요.',
  ),
  MyFaq(
    id: 'account-companion',
    categoryId: 'account',
    title: '공동집사는 어떻게 초대하나요?',
    body:
        '공동집사는 출시 후 추가할 예정이에요. 현재는 다른 사용자를 초대하거나 반려동물 기록을 함께 관리할 수 없어요.\n\n기능이 제공되면 이용 방법을 안내할게요.',
  ),
  MyFaq(
    id: 'account-policy',
    categoryId: 'account',
    title: '약관과 개인정보 처리방침은 어디에서 볼 수 있나요?',
    body:
        '마이페이지의 약관 및 정책에서 항목별 안내를 확인할 수 있어요.\n\n현재 정책 전문은 준비 중이에요. 정식 정책이 등록되면 이곳에서 확인할 수 있어요.',
  ),
  MyFaq(
    id: 'records-edit',
    categoryId: 'records',
    title: '반려동물 기록은 어디에서 수정하나요?',
    body:
        '기록 목록에서 수정할 항목을 선택한 뒤 상세 화면의 수정 버튼을 눌러 주세요.\n\n기존 입력값이 채워진 화면에서 내용을 변경하고 저장할 수 있어요. 저장에 실패하면 안내를 확인한 뒤 다시 시도해 주세요.',
  ),
  MyFaq(
    id: 'records-date',
    categoryId: 'records',
    title: '오늘이 아닌 날짜로 기록할 수 있나요?',
    body:
        '기록 화면에서 원하는 날짜를 선택한 뒤 기록을 추가해 주세요. 선택한 날짜를 기준으로 입력 화면이 열려요.\n\n저장하기 전에 입력 화면에 표시된 날짜와 시간을 확인해 주세요.',
  ),
  MyFaq(
    id: 'records-photo',
    categoryId: 'records',
    title: '사진은 모든 기록에 첨부할 수 있나요?',
    body:
        '현재 급식 기록을 새로 작성할 때 사진 1장을 추가할 수 있어요. 사진 추가 버튼이 없는 기록에서는 사진 첨부를 제공하지 않아요.\n\n급식 기록을 수정할 때는 기존 사진을 확인할 수 있지만 사진 추가나 교체는 할 수 없어요.',
  ),
  MyFaq(
    id: 'routine-repeat',
    categoryId: 'routine',
    title: '루틴 반복 요일은 어떻게 정하나요?',
    body:
        '루틴 만들기에서 매일, 매주, 격주, 매월 중 반복 방식을 선택할 수 있어요.\n\n선택한 방식에 따라 요일이나 날짜를 설정하고 저장해 주세요. 등록한 루틴은 루틴 목록과 달력에서 확인할 수 있어요.',
  ),
  MyFaq(
    id: 'routine-complete',
    categoryId: 'routine',
    title: '완료 체크를 취소할 수 있나요?',
    body:
        '오늘 루틴 목록에서 완료 상태를 변경할 수 있어요. 완료한 항목을 다시 누르면 완료를 취소할 수 있어요.\n\n처리에 실패하면 이전 상태로 돌아가므로, 완료 표시와 오류 안내를 확인해 주세요.',
  ),
  MyFaq(
    id: 'routine-schedule',
    categoryId: 'routine',
    title: '병원 일정 같은 단발 일정도 저장되나요?',
    body:
        '루틴의 일정 만들기에서 병원 예약이나 미용처럼 한 번만 필요한 일정을 등록할 수 있어요.\n\n날짜와 시간, 장소, 메모를 입력하고 저장해 주세요. 장소는 직접 입력하며 지도 검색은 제공하지 않아요. 등록한 일정은 일정 상세에서 수정할 수 있어요.',
  ),
  MyFaq(
    id: 'community-image',
    categoryId: 'community',
    title: '게시글 이미지는 어디에서 볼 수 있나요?',
    body:
        '게시글을 누르면 상세 화면에서 본문과 첨부 이미지를 확인할 수 있어요.\n\n새 글에는 사진을 최대 5장까지 첨부할 수 있어요. 글을 등록한 후 수정 화면에서는 기존 사진을 확인할 수 있지만 추가하거나 교체할 수 없어요.',
  ),
  MyFaq(
    id: 'community-poll',
    categoryId: 'community',
    title: '투표에 참여할 수 있나요?',
    body:
        '투표가 있는 게시글에서 선택지를 고른 뒤 투표하기를 눌러 주세요. 다른 선택지를 고르고 투표 변경을 눌러 선택을 바꿀 수도 있어요.\n\n새 글을 작성할 때는 투표 선택지를 2~5개 입력할 수 있어요. 글 등록 후에는 투표 내용을 수정할 수 없어요.',
  ),
  MyFaq(
    id: 'community-activity',
    categoryId: 'community',
    title: '내가 쓴 글과 댓글은 어디에서 확인하나요?',
    body:
        'My의 나의 활동에서 내가 쓴 글, 공감한 글, 댓글 남긴 글을 확인할 수 있어요.\n\n'
        '작성·공감·댓글을 남긴 최신순으로 표시하며, 댓글과 답글은 같은 게시글당 한 번만 보여요.\n\n'
        '게시글을 누르면 상세로, 내 댓글 미리보기를 누르면 댓글 위치로 이동해요. 공감을 취소하거나 내 댓글을 모두 삭제하면 해당 목록에서 제외돼요.',
  ),
  MyFaq(
    id: 'account-inquiry',
    categoryId: 'account',
    title: '1대1 문의의 답변은 어디로 오나요?',
    body:
        '마이페이지의 1대1 문의하기에서 유형, 답변받을 이메일, 제목과 내용을 입력해 주세요.\n\n접수 완료 안내가 표시되면 입력한 이메일로 답변받는 방식이에요. 접수 실패 안내가 나오면 작성 내용은 유지되며 다시 시도할 수 있어요. 현재 접수 기능은 연결을 준비 중이어서 이용이 제한될 수 있어요.',
  ),
  MyFaq(
    id: 'community-report',
    categoryId: 'community',
    title: '게시글은 어떻게 신고하나요?',
    body:
        '다른 사용자의 게시글 상세에서 더보기 메뉴의 신고하기를 선택해 주세요. 사유를 선택하고 필요한 내용을 적어 접수할 수 있어요. 기타 사유는 상세 내용이 필요해요.\n\n접수 완료 안내가 없으면 접수 여부를 확인할 수 없어요. 현재 접수 기능은 연결을 준비 중이에요. 본인 게시글과 댓글·답글에는 신고 버튼을 제공하지 않아요.',
  ),
  MyFaq(
    id: 'community-block',
    categoryId: 'community',
    title: '작성자 차단과 해제는 어디에서 하나요?',
    body:
        '다른 사용자의 게시글 상세에서 더보기 메뉴의 작성자 차단을 선택할 수 있어요. 마이페이지 또는 설정의 차단 목록에서 해제할 수 있어요.\n\n현재 차단 기능은 연결을 준비 중이에요. 실패 안내가 표시되면 처리 완료 여부를 확인할 수 없어요.',
  ),
  MyFaq(
    id: 'community-news',
    categoryId: 'community',
    title: '소식 카테고리에는 누가 글을 쓸 수 있나요?',
    body:
        '소식은 운영자가 게시글을 작성하는 카테고리예요. 일반 사용자는 소식을 읽을 수 있지만 소식 카테고리에 글을 작성할 수 없어요.',
  ),
];

MyNotice? findMyNotice(String id) {
  for (final notice in myNotices) {
    if (notice.id == id) return notice;
  }
  return null;
}

MyFaqCategory? findMyFaqCategory(String id) {
  for (final category in myFaqCategories) {
    if (category.id == id) return category;
  }
  return null;
}

List<MyFaq> myFaqsForCategory(String categoryId) =>
    myFaqs.where((faq) => faq.categoryId == categoryId).toList();

MyFaq? findMyFaq(String id) {
  for (final faq in myFaqs) {
    if (faq.id == id) return faq;
  }
  return null;
}
