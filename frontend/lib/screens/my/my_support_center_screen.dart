import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'my_support_data.dart';
import 'my_support_widgets.dart';

class MySupportCenterScreen extends StatelessWidget {
  const MySupportCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '고객센터',
        showBackButton: true,
        centerTitle: true,
        onBack: () => goBackOrFallback(context, '/my'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: [
          const MySupportLead('궁금한 점을 빠르게 찾을 수 있도록 주제별 도움말을 제공합니다.'),
          const SizedBox(height: 14),
          MySupportCard(
            children: [
              for (var index = 0; index < myFaqCategories.length; index++)
                MySupportRow(
                  title: myFaqCategories[index].title,
                  iconLabel: myFaqCategories[index].iconLabel,
                  showTopBorder: index > 0,
                  onTap: () =>
                      context.push('/my/support/${myFaqCategories[index].id}'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppText(
                  '원하는 답을 찾지 못했나요?',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
                const SizedBox(height: 6),
                const AppText(
                  '문의 유형과 내용을 남기면 운영팀이 확인 후 답변합니다.',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => context.push('/my/inquiry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const AppText(
                    '1대1 문의하기',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MyFaqCategoryScreen extends StatelessWidget {
  final String categoryId;

  const MyFaqCategoryScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final category = findMyFaqCategory(categoryId);
    final faqs = myFaqsForCategory(categoryId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: category?.title ?? '고객센터',
        showBackButton: true,
        centerTitle: true,
        onBack: () => goBackOrFallback(context, '/my/support'),
      ),
      body: category == null
          ? const MySupportNotFound('카테고리를 찾을 수 없어요')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
              children: [
                MySupportLead(category.lead),
                const SizedBox(height: 14),
                MySupportSectionTitle(category.title),
                const SizedBox(height: 10),
                MySupportCard(
                  children: [
                    for (var index = 0; index < faqs.length; index++)
                      MySupportRow(
                        title: 'Q. ${faqs[index].title}',
                        showTopBorder: index > 0,
                        onTap: () =>
                            context.push('/my/support/faq/${faqs[index].id}'),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class MyFaqDetailScreen extends StatelessWidget {
  final String faqId;

  const MyFaqDetailScreen({super.key, required this.faqId});

  @override
  Widget build(BuildContext context) {
    final faq = findMyFaq(faqId);
    final category = faq == null ? null : findMyFaqCategory(faq.categoryId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '고객센터',
        showBackButton: true,
        centerTitle: true,
        onBack: () => goBackOrFallback(context, '/my/support'),
      ),
      body: faq == null
          ? const MySupportNotFound('질문을 찾을 수 없어요')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
              children: [
                MySupportArticleCard(
                  title: faq.title,
                  meta: category?.title ?? '고객센터',
                  body: faq.body,
                ),
              ],
            ),
    );
  }
}
