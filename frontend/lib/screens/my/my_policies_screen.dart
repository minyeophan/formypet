import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/app_text.dart';
import 'my_policy_data.dart';

class MyPoliciesScreen extends StatelessWidget {
  const MyPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '약관 및 정책',
        showBackButton: true,
        centerTitle: true,
        onBack: () => _goBack(context, '/my'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < myPolicies.length; index++)
                  _PolicyRow(
                    policy: myPolicies[index],
                    showTopBorder: index > 0,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MyPolicyDetailScreen extends StatelessWidget {
  final String policyId;

  const MyPolicyDetailScreen({super.key, required this.policyId});

  @override
  Widget build(BuildContext context) {
    final policy = findMyPolicy(policyId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '약관 상세',
        showBackButton: true,
        centerTitle: true,
        onBack: () => _goBack(context, '/my/policies'),
      ),
      body: policy == null
          ? const Center(
              child: AppText(
                '약관을 찾을 수 없어요',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        policy.title,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                      const SizedBox(height: 14),
                      AppText(
                        policy.body,
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  final MyPolicy policy;
  final bool showTopBorder;

  const _PolicyRow({required this.policy, required this.showTopBorder});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: () => context.push('/my/policies/${policy.id}'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: showTopBorder
                ? const Border(top: BorderSide(color: AppColors.border))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: AppText(
                  policy.title,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const AppDisclosureChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

void _goBack(BuildContext context, String fallbackRoute) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallbackRoute);
}
