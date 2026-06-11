import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../widgets/app_header.dart';
import 'my_support_data.dart';
import 'my_support_widgets.dart';

class MyNoticesScreen extends StatelessWidget {
  const MyNoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '공지사항',
        showBackButton: true,
        centerTitle: true,
        onBack: () => goBackOrFallback(context, '/my'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: [
          const MySupportLead('서비스 변경, 점검, 새 기능 소식을 시간순으로 확인합니다.'),
          const SizedBox(height: 14),
          const MySupportSectionTitle('최근 공지'),
          const SizedBox(height: 10),
          MySupportCard(
            children: [
              for (var index = 0; index < myNotices.length; index++)
                MySupportRow(
                  title: myNotices[index].title,
                  showTopBorder: index > 0,
                  onTap: () =>
                      context.push('/my/notices/${myNotices[index].id}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MyNoticeDetailScreen extends StatelessWidget {
  final String noticeId;

  const MyNoticeDetailScreen({super.key, required this.noticeId});

  @override
  Widget build(BuildContext context) {
    final notice = findMyNotice(noticeId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '공지사항',
        showBackButton: true,
        centerTitle: true,
        onBack: () => goBackOrFallback(context, '/my/notices'),
      ),
      body: notice == null
          ? const MySupportNotFound('공지사항을 찾을 수 없어요')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
              children: [
                MySupportArticleCard(
                  title: notice.title,
                  meta: '공지사항 · ${notice.date}',
                  body: notice.body,
                ),
              ],
            ),
    );
  }
}
