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
  final String iconLabel;
  final String lead;

  const MyFaqCategory({
    required this.id,
    required this.title,
    required this.iconLabel,
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

const myNotices = [
  MyNotice(
    id: 'routine',
    title: '루틴 알림 안정화 안내',
    date: '2026.06.09',
    body:
        '안녕하세요, 펫일기 팀입니다.\n\n'
        '루틴 알림 수신 상태를 더 정확히 확인할 수 있도록 알림 표시 방식을 개선할 예정입니다.\n\n'
        '이번 변경은 알림 설정 화면과 루틴 상세 화면의 안내 문구에 먼저 반영됩니다. 실제 발송 정책과 서버 연동 범위는 추후 업데이트 공지에서 다시 안내드리겠습니다.',
  ),
  MyNotice(
    id: 'records',
    title: '기록 입력 화면 개선 안내',
    date: '2026.06.05',
    body:
        '기록 입력 화면에서 날짜 흐름을 더 명확하게 다듬었습니다.\n\n'
        '기록 메인에서 선택한 날짜가 급식, 음수, 배변, 산책 등 입력 화면까지 유지됩니다. 저장 후에도 같은 날짜의 기록 목록으로 돌아가도록 개선할 예정입니다.\n\n'
        '기타 기록과 사진 첨부 범위는 실제 구현 단계에서 순차적으로 확정합니다.',
  ),
  MyNotice(
    id: 'maintenance',
    title: '정기 점검 예정 안내',
    date: '2026.06.01',
    body:
        '서비스 안정화를 위해 정기 점검 화면 흐름을 검토 중입니다.\n\n'
        '점검 시간에는 일부 기록 동기화와 알림 수신이 잠시 지연될 수 있습니다.\n\n'
        '정확한 점검 시간과 영향 범위는 운영 일정이 확정되면 다시 안내하겠습니다.',
  ),
];

const myFaqCategories = [
  MyFaqCategory(
    id: 'account',
    title: '계정 관련',
    iconLabel: '계',
    lead: '계정, 로그인, 공동집사, 약관 확인과 관련된 질문을 모았습니다.',
  ),
  MyFaqCategory(
    id: 'records',
    title: '기록 관련',
    iconLabel: '기',
    lead: '반려동물 기록 작성, 날짜, 사진 첨부와 관련된 질문을 모았습니다.',
  ),
  MyFaqCategory(
    id: 'routine',
    title: '루틴 관련',
    iconLabel: '루',
    lead: '루틴 반복, 완료 체크, 일정 저장과 관련된 질문을 모았습니다.',
  ),
  MyFaqCategory(
    id: 'community',
    title: '커뮤니티 관련',
    iconLabel: '커',
    lead: '게시글, 이미지, 투표, 나의 활동과 관련된 질문을 모았습니다.',
  ),
];

const myFaqs = [
  MyFaq(
    id: 'account-email',
    categoryId: 'account',
    title: '로그인한 이메일을 변경할 수 있나요?',
    body:
        '로그인 이메일은 계정 식별에 사용하는 정보라 앱 안에서는 읽기 전용으로 표시합니다.\n\n'
        '이메일 변경이 필요하면 본인 확인이 필요한 항목으로 분류해 1대1 문의에서 처리하는 흐름을 우선 검토합니다.\n\n'
        '문의할 때에는 현재 로그인 이메일과 변경을 원하는 이메일을 함께 적어 주세요. 실제 변경 가능 여부는 운영 정책과 인증 방식이 확정된 뒤 안내합니다.',
  ),
  MyFaq(
    id: 'account-companion',
    categoryId: 'account',
    title: '공동집사는 어떻게 초대하나요?',
    body:
        '공동집사는 반려동물 기록을 함께 관리할 보호자를 초대하는 기능입니다.\n\n'
        '초대 화면에서는 초대할 사용자의 이메일이나 초대 링크를 입력하고, 상대방이 수락하면 같은 반려동물의 기록과 루틴을 함께 볼 수 있게 구성합니다.\n\n'
        '초대 권한, 대표 집사 권한, 공동집사 삭제 기준은 실제 구현 단계에서 확정합니다.',
  ),
  MyFaq(
    id: 'account-policy',
    categoryId: 'account',
    title: '약관과 개인정보 처리방침은 어디에서 볼 수 있나요?',
    body:
        '약관과 개인정보 처리방침은 My의 약관 및 정책 화면에서 확인할 수 있습니다.\n\n'
        '서비스 이용약관, 개인정보 처리방침, 운영정책, 위치기반 서비스 이용약관, 마케팅 정보 수신 동의를 목록으로 제공합니다.\n\n'
        '중요한 정책 변경이 있으면 공지사항과 앱 내 안내로 다시 알립니다.',
  ),
  MyFaq(
    id: 'records-edit',
    categoryId: 'records',
    title: '반려동물 기록은 어디에서 수정하나요?',
    body:
        '기록 목록에서 항목을 선택하면 상세 화면으로 들어가고, 상세 화면에서 수정 또는 삭제로 이어지는 흐름을 기준으로 설계합니다.\n\n'
        '상세 화면에서는 작성 날짜, 시간, 메모, 사진, 기록 타입별 입력값을 확인합니다.\n\n'
        '수정 화면은 기존 입력값을 유지한 상태로 열리고, 저장하면 해당 날짜의 기록 목록으로 돌아오게 구성합니다.',
  ),
  MyFaq(
    id: 'records-date',
    categoryId: 'records',
    title: '오늘이 아닌 날짜로 기록할 수 있나요?',
    body:
        '오늘이 아닌 날짜로 기록하고 싶을 때는 기록 메인에서 날짜를 먼저 선택합니다.\n\n'
        '선택한 날짜는 급식, 음수, 배변, 산책, 몸무게, 병원, 영양, 일기, 기타 입력 화면까지 유지됩니다.\n\n'
        '입력 화면에서는 날짜를 다시 바꾸지 않고, 시간만 현재 시간으로 갱신할 수 있게 구성합니다.',
  ),
  MyFaq(
    id: 'records-photo',
    categoryId: 'records',
    title: '사진은 모든 기록에 첨부할 수 있나요?',
    body:
        '사진 첨부는 기록 타입별로 필요한 범위를 나누어 적용합니다.\n\n'
        '급식처럼 사진 확인이 자연스러운 기록부터 우선 연결하고, 다른 기록 타입은 저장 방식과 화면 구성을 확정한 뒤 확장합니다.\n\n'
        '사진 업로드에 실패했을 때 기록을 유지할지, 기록 생성까지 되돌릴지는 백엔드 저장 정책과 함께 확정합니다.',
  ),
  MyFaq(
    id: 'routine-repeat',
    categoryId: 'routine',
    title: '루틴 반복 요일은 어떻게 정하나요?',
    body:
        '루틴은 반복해서 챙겨야 하는 케어를 등록하는 기능입니다.\n\n'
        '매일, 매주, 격주, 매월 반복을 선택할 수 있고 주간 반복은 필요한 요일을 함께 고릅니다.\n\n'
        '반복 규칙은 오늘 루틴 목록과 월간 달력에 반영되어 사용자가 예정된 케어를 빠르게 확인할 수 있게 합니다.',
  ),
  MyFaq(
    id: 'routine-complete',
    categoryId: 'routine',
    title: '완료 체크를 취소할 수 있나요?',
    body:
        '완료 체크는 오늘 해야 할 루틴 목록에서 바로 바꿀 수 있게 유지합니다.\n\n'
        '이미 완료한 루틴을 다시 누르면 완료를 해제하는 흐름으로 설계합니다.\n\n'
        '체크 요청이 실패하면 화면 상태를 이전 값으로 되돌려 사용자가 실제 저장 여부를 헷갈리지 않게 합니다.',
  ),
  MyFaq(
    id: 'routine-schedule',
    categoryId: 'routine',
    title: '병원 일정 같은 단발 일정도 저장되나요?',
    body:
        '병원 예약이나 미용 일정처럼 한 번만 필요한 일정은 반복 루틴과 별도 흐름으로 다룹니다.\n\n'
        '일정 추가 화면은 준비되어 있으며, 일정명, 날짜, 시간, 메모를 입력하는 구조를 우선 검토합니다.\n\n'
        '실제 저장 API와 목록 연동이 확정되면 루틴 화면의 일정 탭에서 등록한 일정을 보여줍니다.',
  ),
  MyFaq(
    id: 'community-image',
    categoryId: 'community',
    title: '게시글 이미지는 어디에서 볼 수 있나요?',
    body:
        '커뮤니티 게시글은 피드에서 요약을 확인하고 상세 화면에서 본문과 이미지를 확인하는 흐름으로 확장합니다.\n\n'
        '피드에서는 대표 이미지나 첨부 여부를 간결하게 보여주고, 상세 화면에서는 첨부 이미지를 더 크게 볼 수 있게 구성합니다.\n\n'
        '이미지 최대 개수와 표시 방식은 글쓰기 화면의 첨부 정책과 함께 맞춥니다.',
  ),
  MyFaq(
    id: 'community-poll',
    categoryId: 'community',
    title: '투표에 참여할 수 있나요?',
    body:
        '투표는 글쓰기 화면에서 질문과 선택지를 추가해 등록하는 방향으로 준비 중입니다.\n\n'
        '피드와 상세 화면에서는 투표 질문, 선택지, 참여 여부, 결과 표시를 함께 보여주는 구성을 검토합니다.\n\n'
        '이미 참여한 투표를 다시 수정할 수 있는지 여부는 서버 정책이 확정된 뒤 안내합니다.',
  ),
  MyFaq(
    id: 'community-activity',
    categoryId: 'community',
    title: '내가 쓴 글과 댓글은 어디에서 확인하나요?',
    body:
        '내가 쓴 글, 공감한 글, 댓글 남긴 글은 My의 나의 활동 메뉴에서 나누어 볼 수 있게 설계합니다.\n\n'
        '각 목록은 커뮤니티 카드 패턴을 재사용하되 내 활동 맥락에 필요한 상태만 간결하게 보여줍니다.\n\n'
        '게시글 상세 화면이 연결되면 나의 활동 목록에서도 같은 상세 화면으로 이동하게 구성합니다.',
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
