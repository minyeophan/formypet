import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/activity_record.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';
import 'record_support.dart';

class RecordDetailScreen extends ConsumerWidget {
  final String recordId;

  const RecordDetailScreen({super.key, required this.recordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petProvider);
    final record = state.records
        .where(
          (candidate) =>
              candidate.id == recordId &&
              candidate.petId == state.activePetId &&
              isRecordDetailSupported(candidate.typeId),
        )
        .firstOrNull;

    if (record == null) {
      return const _RecordNotFoundScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: AppInlineHeader(
                  title: '${recordTypeLabel(record.typeId)} 상세',
                  onBack: () => _goBack(context, fallback: '/records'),
                  trailing: TextButton(
                    key: const Key('record-detail-edit-button'),
                    onPressed: () => context.push('/records/${record.id}/edit'),
                    child: const AppText(
                      '수정',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList.list(
                children: [
                  _SectionBlock(
                    title: '날짜/시간',
                    child: Row(
                      children: [
                        Expanded(
                          child: _ValueBox(
                            key: const Key('record-detail-date-label'),
                            text: record.date,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ValueBox(
                            key: const Key('record-detail-time-label'),
                            text: recordTimeLabel(record.time),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  ..._detailSections(record),
                  if (record.typeId == 'meal') ...[
                    const SizedBox(height: 22),
                    _MealPhotoSection(record: record),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordNotFoundScreen extends StatelessWidget {
  const _RecordNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: AppInlineHeader(
                title: '기록 상세',
                onBack: () => _goBack(context, fallback: '/records'),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    key: const Key('record-detail-not-found'),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppText(
                          '기록을 찾을 수 없어요',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/records'),
                          child: const AppText(
                            '기록으로 돌아가기',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _detailSections(ActivityRecord record) {
  final detail = record.detail;
  switch (record.typeId) {
    case 'meal':
      return [
        _SectionBlock(
          title: '사료 종류',
          child: _ValueBox(text: mealFoodTypeLabel(detail['foodType'])),
        ),
        const SizedBox(height: 22),
        _SectionBlock(
          title: '상세 정보',
          child: Column(
            children: [
              _ValueRow(label: '사료명', value: detail['product']),
              _ValueRow(
                label: '급여량',
                value: _unitValue(detail['servedAmount'], 'g'),
              ),
              _ValueRow(
                label: '먹은 양',
                value: detail['consumedPercent'] == null
                    ? null
                    : '${detail['consumedPercent']}%',
              ),
              _ValueRow(label: '메모', value: record.note),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _SectionBlock(
          title: '추가 정보',
          child: Column(
            children: [
              _ValueRow(label: '브랜드명', value: detail['brand']),
              _ValueRow(
                label: '급식 방법',
                value: mealFeedingMethodLabel(detail['feedingMethod']),
              ),
            ],
          ),
        ),
      ];
    case 'water':
      return [
        _SectionBlock(
          title: '음수 정보',
          child: _ValueRow(
            label: '음수량',
            value: _unitValue(detail['amount'], 'ml'),
          ),
        ),
      ];
    case 'poop':
      return [
        _SectionBlock(
          title: '종류',
          child: _ValueBox(text: detail['poopShape'] == 'urine' ? '소변' : '대변'),
        ),
        if (detail['poopShape'] != 'urine') ...[
          const SizedBox(height: 22),
          _SectionBlock(
            title: '변 상태',
            child: _ValueBox(text: poopShapeLabel(detail['poopShape'])),
          ),
        ],
        const SizedBox(height: 22),
        _SectionBlock(
          title: '색상',
          child: _ValueBox(text: poopColorLabel(detail['poopColor'])),
        ),
        const SizedBox(height: 22),
        _SectionBlock(
          title: '메모',
          child: _ValueBox(text: record.note ?? ''),
        ),
      ];
    case 'walk':
      return [
        _SectionBlock(
          title: '산책 정보',
          child: Column(
            children: [
              _ValueRow(
                label: '거리',
                value: _unitValue(detail['distance'], 'km'),
              ),
              _ValueRow(label: '산책 메모', value: record.note),
            ],
          ),
        ),
      ];
    case 'medicine':
      return [
        _SectionBlock(
          title: '영양/약 정보',
          child: Column(
            children: [
              _ValueRow(label: '이름', value: detail['medicineName']),
              _ValueRow(label: '용량', value: detail['dosage']),
            ],
          ),
        ),
      ];
    case 'vet':
      return [
        _SectionBlock(
          title: '병원 정보',
          child: Column(
            children: [
              _ValueRow(label: '병원명', value: detail['vetClinicName']),
              _ValueRow(label: '방문 사유', value: detail['vetVisitReason']),
              _ValueRow(label: '진료/처방 메모', value: detail['vetTreatment']),
            ],
          ),
        ),
      ];
    case 'weight':
      return [
        _SectionBlock(
          title: '몸무게 정보',
          child: _ValueRow(
            label: '몸무게',
            value: _unitValue(weightValue(record), 'kg'),
          ),
        ),
      ];
    case 'diary':
    case 'etc':
      return [
        _SectionBlock(
          title: '메모',
          child: _ValueBox(text: record.note ?? '', minHeight: 120),
        ),
      ];
    default:
      return const [];
  }
}

class _MealPhotoSection extends StatelessWidget {
  final ActivityRecord record;

  const _MealPhotoSection({required this.record});

  @override
  Widget build(BuildContext context) {
    return _SectionBlock(
      key: const Key('record-detail-photo-section'),
      title: '사진',
      child: record.mediaUrls.isEmpty
          ? const _ValueBox(text: '등록된 사진이 없어요')
          : SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final url = record.mediaUrls[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AuthenticatedNetworkImage(
                      url: url,
                      width: 108,
                      height: 108,
                      fit: BoxFit.cover,
                      fallback: Container(
                        width: 108,
                        height: 108,
                        color: AppColors.surfaceSoft,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemCount: record.mediaUrls.length,
              ),
            ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionBlock({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          title,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final Object? value;

  const _ValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: AppText(
                label,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ),
          Expanded(child: _ValueBox(text: _displayValue(value))),
        ],
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String text;
  final double minHeight;

  const _ValueBox({super.key, required this.text, this.minHeight = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        text.trim().isEmpty ? '-' : text,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: text.trim().isEmpty ? AppColors.muted : AppColors.text,
      ),
    );
  }
}

String? _unitValue(Object? value, String unit) {
  if (value == null) return null;
  return '${numberLabel(value)}$unit';
}

String _displayValue(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? '' : text;
}

void _goBack(BuildContext context, {required String fallback}) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallback);
}
