import '../../core/visuals/app_visual_id.dart';

const List<String> kCommunityCategories = [
  'CARE',
  'FOOD',
  'OUTING',
  'SHOW',
  'QUESTION',
  'FREE',
  'ADOPTION',
  'RESCUE',
  'NEWS',
  'EVENT',
];

const List<String> kCommunityFeedTabs = [
  'ALL',
  'POPULAR',
  ...kCommunityCategories,
];

const Map<String, String> kCommunityCategoryLabels = {
  'ALL': '전체',
  'POPULAR': '인기',
  'CARE': '케어',
  'FOOD': '사료/간식',
  'OUTING': '산책/외출',
  'SHOW': '자랑',
  'QUESTION': '질문',
  'FREE': '자유',
  'ADOPTION': '입양',
  'RESCUE': '구조',
  'NEWS': '소식',
  'EVENT': '이벤트',
};

String? formatCommunityRelativeTime(String raw, {DateTime? now}) {
  final created = DateTime.tryParse(raw.trim());
  if (created == null) return null;
  final difference = (now ?? DateTime.now()).difference(created.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return '방금 전';
  if (difference.inHours < 1) return '${difference.inMinutes}분 전';
  if (difference.inDays < 1) return '${difference.inHours}시간 전';
  if (difference.inDays < 7) return '${difference.inDays}일 전';
  final local = created.toLocal();
  return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
}

String normalizeCommunitySourceKey(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return '';
  final upper = value.toUpperCase();
  if (upper == 'POPULAR') return 'popular';
  if (upper == 'ALL') return 'all';
  return kCommunityCategories.contains(upper) ? upper : '';
}

bool isCommunitySourceKey(String? raw) =>
    normalizeCommunitySourceKey(raw).isNotEmpty;

String communitySourceLabel(String? raw) {
  final key = normalizeCommunitySourceKey(raw);
  if (key.isEmpty) return '';
  final labelKey = key == 'popular'
      ? 'POPULAR'
      : key == 'all'
      ? 'ALL'
      : key;
  return kCommunityCategoryLabels[labelKey] ?? '';
}

AppVisualId communityVisualId(String category) =>
    switch (category.toUpperCase()) {
      'ALL' => AppVisualId.communityAll,
      'POPULAR' => AppVisualId.communityPopular,
      'CARE' => AppVisualId.communityCare,
      'FOOD' => AppVisualId.communityFood,
      'OUTING' => AppVisualId.communityOuting,
      'SHOW' => AppVisualId.communityShow,
      'QUESTION' => AppVisualId.communityQuestion,
      'FREE' => AppVisualId.communityFree,
      'ADOPTION' => AppVisualId.communityAdoption,
      'RESCUE' => AppVisualId.communityRescue,
      'NEWS' => AppVisualId.communityNews,
      'EVENT' => AppVisualId.communityEvent,
      _ => AppVisualId.genericUnknown,
    };
