import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/pet_colors.dart';
import '../../core/pet_taxonomy.dart';
import '../../models/activity_record.dart';
import '../../models/pet.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';
import 'pet_confirm_dialog.dart';

class PetDetailScreen extends ConsumerWidget {
  final String petId;
  const PetDetailScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petProvider);
    final pet = state.pets.where((p) => p.id == petId).firstOrNull;
    final appBar = AppHeader(
      title: pet?.name ?? '반려동물 상세',
      showBackButton: true,
      centerTitle: true,
      onBack: () => _goBackToMy(context),
      actions: pet == null
          ? null
          : [
              AppHeaderIconButton(
                icon: Icons.edit_outlined,
                tooltip: '수정',
                onTap: () => context.push('/pet/${pet.id}/edit'),
              ),
            ],
    );

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (pet == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        body: const Center(child: AppText('반려동물을 찾을 수 없습니다')),
      );
    }

    final latestWeight = ref.watch(latestPetWeightProvider(pet.id));
    final color = colorPairForHex(pet.accentColor);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHero(
              pet: pet,
              accent: color.accent,
              bgLight: color.bgLight,
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: '기본정보',
              child: Column(
                children: [
                  _InfoRow(label: '나이', value: _ageLabel(pet.birthDate)),
                  _InfoRow(
                    label: '최근 체중',
                    value: latestWeight.when(
                      data: _weightRecordLabel,
                      loading: () => '조회 중',
                      error: (_, _) => '-',
                    ),
                  ),
                  _InfoRow(label: '성별', value: _genderLabel(pet.gender)),
                  _InfoRow(label: '중성화', value: _neuteredLabel(pet.neutered)),
                  _InfoRow(
                    label: '함께한 날',
                    value: _daysTogetherLabel(pet.adoptionDate),
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: '추가정보',
              child: Column(
                children: [
                  _InfoRow(label: '종', value: speciesLabel(pet.species)),
                  _InfoRow(label: '품종/하위종', value: _textOrDash(pet.breed)),
                  _InfoRow(
                    label: '생년월일',
                    value: _birthDateLabel(pet.birthDate),
                  ),
                  _InfoRow(
                    label: '함께한 날',
                    value: _dateOrDash(pet.adoptionDate),
                  ),
                  _InfoRow(
                    label: '특수상태',
                    value: _specialStatusLabel(pet.specialStatus),
                  ),
                  _InfoRow(label: '성격', value: _textOrDash(pet.personality)),
                  _InfoRow(
                    label: '보호자 호칭',
                    value: _textOrDash(pet.guardianNickname),
                  ),
                  _InfoRow(
                    label: '알러지·특이사항',
                    value: _textOrDash(pet.specialNotes),
                  ),
                  _InfoRow(label: '질병', value: _textOrDash(pet.diseases)),
                  _InfoRow(
                    label: '주치의·병원',
                    value: _textOrDash(pet.primaryHospitalName),
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _DangerCard(
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => PetConfirmDialog(
                    title: '반려동물 삭제',
                    body: '${pet.name}을(를) 삭제하시겠습니까?',
                    actions: [
                      PetConfirmDialogAction(
                        label: '취소',
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                      ),
                      PetConfirmDialogAction(
                        label: '삭제',
                        isDanger: true,
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(petProvider.notifier).deletePet(petId);
                  if (!context.mounted) return;
                  if (!ref.read(petProvider).hasOnboarded) return;
                  _goBackToMy(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _goBackToMy(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/my');
}

class _ProfileHero extends StatelessWidget {
  final Pet pet;
  final Color accent;
  final Color bgLight;

  const _ProfileHero({
    required this.pet,
    required this.accent,
    required this.bgLight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AuthenticatedNetworkImage(
              url: pet.profileImageUrl,
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              fallback: Container(
                width: 92,
                height: 92,
                color: bgLight,
                alignment: Alignment.center,
                child: AppText(speciesEmoji(pet.species), fontSize: 38),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  pet.name,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                AppText(
                  [
                    speciesLabel(pet.species),
                    if (_compactText(pet.breed) != null) pet.breed!,
                  ].join(' · '),
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Container(
                  width: 34,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(99),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const _InfoRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 106,
            child: AppText(
              label,
              color: AppColors.textSecondary,
              fontSize: 13,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: AppText(
              value,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  final VoidCallback onDelete;

  const _DangerCard({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onDelete,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    '삭제',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _ageLabel(String? birthDateIso) {
  final birth = DateTime.tryParse(birthDateIso ?? '');
  if (birth == null) return '-';
  final now = DateTime.now();
  var years = now.year - birth.year;
  final hasBirthdayPassed =
      now.month > birth.month ||
      (now.month == birth.month && now.day >= birth.day);
  if (!hasBirthdayPassed) {
    years -= 1;
  }
  return '${years < 0 ? 0 : years}살';
}

String _daysTogetherLabel(String? adoptionDateIso) {
  final adoptionDate = DateTime.tryParse(adoptionDateIso ?? '');
  if (adoptionDate == null) return '-';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(
    adoptionDate.year,
    adoptionDate.month,
    adoptionDate.day,
  );
  final days = today.difference(target).inDays + 1;
  if (days < 1) return '-';
  return '$days일';
}

String _dateOrDash(String? isoDate) {
  final date = DateTime.tryParse(isoDate ?? '');
  if (date == null) return '-';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _birthDateLabel(String? isoDate) {
  final date = DateTime.tryParse(isoDate ?? '');
  if (date == null) return '몰라요';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _genderLabel(String? gender) {
  if (gender == 'male') return '남아';
  if (gender == 'female') return '여아';
  return '-';
}

String _neuteredLabel(bool? neutered) {
  if (neutered == null) return '-';
  return neutered ? '완료' : '미완료';
}

String _specialStatusLabel(String? status) {
  const labels = {
    'senior': '노령',
    'pregnant': '임신',
    'disabled': '장애',
    'recovering': '회복 중',
    'none': '없음',
  };
  final value = _compactText(status);
  if (value == null) return '-';
  return labels[value] ?? value;
}

String _textOrDash(String? value) => _compactText(value) ?? '-';

String? _compactText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _weightRecordLabel(ActivityRecord? record) {
  if (record == null) return '-';
  final value = record.detail['weight'] ?? record.detail['value'];
  if (value == null) return '-';
  final parsed = double.tryParse(value.toString());
  final valueLabel = parsed == null ? value.toString() : _numberLabel(parsed);
  final unit = record.detail['unit']?.toString();
  return unit == null || unit.isEmpty ? '${valueLabel}kg' : '$valueLabel$unit';
}

String _numberLabel(double value) {
  final rounded = value.toStringAsFixed(1);
  return rounded.endsWith('.0')
      ? rounded.substring(0, rounded.length - 2)
      : rounded;
}
