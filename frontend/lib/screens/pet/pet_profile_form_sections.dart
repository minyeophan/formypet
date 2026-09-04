part of 'pet_profile_form.dart';

class _IdentitySection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController breedCtrl;
  final String species;
  final ValueChanged<String> onSpeciesSelected;
  final VoidCallback onBreedTap;

  const _IdentitySection({
    required this.nameCtrl,
    required this.breedCtrl,
    required this.species,
    required this.onSpeciesSelected,
    required this.onBreedTap,
  });

  @override
  Widget build(BuildContext context) {
    final breed = _compactText(breedCtrl.text);
    return PetFormSection(
      key: const Key('pet-edit-identity-section'),
      title: '기본 프로필',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PetTextField(label: '이름', controller: nameCtrl, hintText: '반려동물 이름'),
          const SizedBox(height: 12),
          const AppText('동물 종류', fontWeight: FontWeight.bold),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final textWidth = (constraints.maxWidth - 16) / 3 - 14;
              var labelHeight = 0.0;
              for (final item in kPetSpecies) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: item.label,
                    style: DefaultTextStyle.of(context).style.merge(
                      GoogleFonts.notoSansKr(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: textWidth);
                if (painter.height > labelHeight) labelHeight = painter.height;
                painter.dispose();
              }
              return GridView.builder(
                key: const Key('pet-edit-species-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: kPetSpecies.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 64 + labelHeight.ceilToDouble(),
                ),
                itemBuilder: (context, index) {
                  final item = kPetSpecies[index];
                  return PetChoiceButton(
                    leading: SizedBox.square(
                      dimension: 32,
                      child: FittedBox(
                        child: AppVisual(id: item.visualId, size: 32),
                      ),
                    ),
                    label: item.label,
                    selected: species == item.id,
                    onTap: () => onSpeciesSelected(item.id),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          PetPickerField(
            label: '품종/하위종',
            value: breed ?? '선택',
            isPlaceholder: breed == null,
            onTap: onBreedTap,
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final TextEditingController birthCtrl;
  final TextEditingController adoptionCtrl;
  final String? gender;
  final bool? neutered;
  final bool neuteredEnabled;
  final VoidCallback onBirthTap;
  final VoidCallback onAdoptionTap;
  final VoidCallback onBirthUnknownTap;
  final ValueChanged<String> onGenderSelected;
  final ValueChanged<bool> onNeuteredSelected;

  const _ProfileSection({
    required this.birthCtrl,
    required this.adoptionCtrl,
    required this.gender,
    required this.neutered,
    required this.neuteredEnabled,
    required this.onBirthTap,
    required this.onAdoptionTap,
    required this.onBirthUnknownTap,
    required this.onGenderSelected,
    required this.onNeuteredSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PetFormSection(
      key: const Key('pet-edit-profile-section'),
      title: '상세 프로필',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PetDateField(
            label: '생년월일',
            value: birthCtrl.text,
            placeholder: 'YYYY-MM-DD',
            onTap: onBirthTap,
            trailing: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onBirthUnknownTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(44, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const AppText(
                  '생년월일을 몰라요',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          PetDateField(
            label: '함께한 날',
            value: adoptionCtrl.text,
            placeholder: 'YYYY-MM-DD',
            onTap: onAdoptionTap,
            trailing: adoptionCtrl.text.isEmpty
                ? null
                : Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: adoptionCtrl.clear,
                      child: const AppText('날짜 지우기', color: AppColors.primary),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          const AppText('성별', fontWeight: FontWeight.bold),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PetChoiceButton(
                  label: '남아',
                  selected: gender == 'male',
                  onTap: () => onGenderSelected('male'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PetChoiceButton(
                  label: '여아',
                  selected: gender == 'female',
                  onTap: () => onGenderSelected('female'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const AppText('중성화 여부', fontWeight: FontWeight.bold),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PetChoiceButton(
                  label: '완료',
                  selected: neutered == true,
                  enabled: neuteredEnabled,
                  onTap: () => onNeuteredSelected(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PetChoiceButton(
                  label: '미완료',
                  selected: neutered == false,
                  enabled: neuteredEnabled,
                  onTap: () => onNeuteredSelected(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExtraSection extends StatelessWidget {
  final String? specialStatus;
  final Set<String> selectedDiseases;
  final TextEditingController personalityCtrl;
  final TextEditingController guardianCtrl;
  final TextEditingController specialNotesCtrl;
  final TextEditingController hospitalCtrl;
  final ValueChanged<String> onSpecialStatusSelected;
  final VoidCallback onDiseasesTap;

  const _ExtraSection({
    required this.specialStatus,
    required this.selectedDiseases,
    required this.personalityCtrl,
    required this.guardianCtrl,
    required this.specialNotesCtrl,
    required this.hospitalCtrl,
    required this.onSpecialStatusSelected,
    required this.onDiseasesTap,
  });

  @override
  Widget build(BuildContext context) {
    return PetFormSection(
      key: const Key('pet-edit-extra-section'),
      title: '추가 정보',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('특수상태', fontWeight: FontWeight.bold),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final status in _specialStatusOptions) ...[
                Expanded(
                  child: PetChoiceButton(
                    label: status.label,
                    selected: specialStatus == status.value,
                    onTap: () => onSpecialStatusSelected(status.value),
                    dense: true,
                  ),
                ),
                if (status != _specialStatusOptions.last)
                  const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 12),
          PetTextField(label: '성격', controller: personalityCtrl),
          const SizedBox(height: 12),
          PetTextField(label: '보호자 호칭', controller: guardianCtrl),
          const SizedBox(height: 12),
          PetTextField(
            label: '알러지·특이사항',
            controller: specialNotesCtrl,
            minLines: 2,
          ),
          const SizedBox(height: 12),
          PetPickerField(
            key: const Key('pet-edit-diseases-picker'),
            label: '질병',
            value: selectedDiseases.isEmpty
                ? '선택'
                : selectedDiseases.join(', '),
            isPlaceholder: selectedDiseases.isEmpty,
            onTap: onDiseasesTap,
          ),
          const SizedBox(height: 12),
          PetTextField(label: '주치의·병원', controller: hospitalCtrl),
        ],
      ),
    );
  }
}

class _BottomSubmitButton extends StatelessWidget {
  final VoidCallback? onSkipPhoto;
  final String label;
  final String? error;
  final bool isLoading;
  final VoidCallback onTap;

  const _BottomSubmitButton({
    this.onSkipPhoto,
    required this.label,
    this.error,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppText(error!, color: AppColors.danger),
              ),
            if (onSkipPhoto != null)
              TextButton(
                onPressed: isLoading ? null : onSkipPhoto,
                child: const AppText('사진 없이 완료', color: AppColors.primary),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : AppText(
                        label,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPickerTile extends StatelessWidget {
  final XFile? photo;
  final Uint8List? bytes;
  final String? existingUrl;
  final VoidCallback onTap;

  const _PhotoPickerTile({
    required this.photo,
    this.bytes,
    this.existingUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: bytes != null
                    ? Image.memory(
                        bytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.pets,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : AuthenticatedNetworkImage(
                        url: existingUrl,
                        fit: BoxFit.cover,
                        fallback: const Icon(
                          Icons.add_a_photo_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AppText(
                photo?.name ?? (existingUrl == null ? '대표 사진 선택' : '사진 변경'),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _specialStatusOptions = [
  _StatusOption('senior', '노령'),
  _StatusOption('pregnant', '임신'),
  _StatusOption('disabled', '장애'),
  _StatusOption('recovering', '회복 중'),
];

class _StatusOption {
  final String value;
  final String label;

  const _StatusOption(this.value, this.label);
}

List<String> _diseaseValuesFromText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return const [];
  }
  return trimmed
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String? _compactText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
