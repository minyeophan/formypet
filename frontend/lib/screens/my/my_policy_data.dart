class MyPolicy {
  final String id;
  final String title;
  final String body;

  const MyPolicy({required this.id, required this.title, required this.body});
}

const myPolicies = [
  MyPolicy(
    id: 'terms',
    title: '서비스 이용약관',
    body:
        '서비스 이용약관은 펫일기 서비스를 이용할 때 지켜야 할 기본 규칙과 이용 조건을 안내합니다. '
        '회원의 권리와 의무, 서비스 제공 범위, 이용 제한 기준은 추후 확정된 약관 전문으로 교체됩니다.',
  ),
  MyPolicy(
    id: 'privacy',
    title: '개인정보 처리방침',
    body:
        '개인정보 처리방침은 서비스 이용 과정에서 필요한 개인정보의 수집, 이용, 보관, 파기 기준을 안내합니다. '
        '구체적인 항목과 보관 기간은 추후 확정된 방침 전문으로 교체됩니다.',
  ),
  MyPolicy(
    id: 'operation',
    title: '운영정책',
    body:
        '운영정책은 안전한 서비스 이용을 위해 게시물, 기록, 커뮤니티 활동에서 적용되는 운영 기준을 안내합니다. '
        '신고 처리와 이용 제한 절차는 추후 확정된 정책 전문으로 교체됩니다.',
  ),
  MyPolicy(
    id: 'location',
    title: '위치기반 서비스 이용약관',
    body:
        '위치기반 서비스 이용약관은 위치 정보를 활용하는 기능이 제공될 때 적용되는 이용 조건을 안내합니다. '
        '위치 정보의 이용 범위와 보호 기준은 추후 확정된 약관 전문으로 교체됩니다.',
  ),
  MyPolicy(
    id: 'marketing',
    title: '마케팅 정보 수신 동의',
    body:
        '마케팅 정보 수신 동의는 이벤트, 혜택, 서비스 소식 안내를 받을 때 적용되는 내용을 안내합니다. '
        '수신 방법과 철회 방법은 추후 확정된 안내 전문으로 교체됩니다.',
  ),
];

MyPolicy? findMyPolicy(String id) {
  for (final policy in myPolicies) {
    if (policy.id == id) {
      return policy;
    }
  }
  return null;
}
