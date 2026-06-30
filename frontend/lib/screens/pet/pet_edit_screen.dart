import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../core/calendar_ranges.dart';
import '../../core/keyboard_utils.dart';
import '../../core/pet_taxonomy.dart';
import '../../models/pet.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_picker_sheet.dart';
import '../../widgets/app_text.dart';
import '../../widgets/pet_form_fields.dart';
import '../../widgets/record_inputs/record_inputs.dart';
import 'pet_confirm_dialog.dart';

class PetEditScreen extends ConsumerStatefulWidget {
  final String petId;
  const PetEditScreen({super.key, required this.petId});

  @override
  ConsumerState<PetEditScreen> createState() => _PetEditScreenState();
}

class _PetEditScreenState extends ConsumerState<PetEditScreen> {
  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
  final _adoptionCtrl = TextEditingController();
  final _guardianCtrl = TextEditingController();
  final _personalityCtrl = TextEditingController();
  final _specialNotesCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();

  String _species = 'dog';
  String? _gender;
  bool? _neutered;
  bool _birthDateUnknown = false;
  String? _specialStatus;
  final Set<String> _selectedDiseases = {};
  XFile? _photo;
  bool _isLoading = false;
  String? _error;
  String? _hydratedPetId;

  @override
  void didUpdateWidget(covariant PetEditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId != widget.petId) {
      _resetHydration();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _birthCtrl.dispose();
    _adoptionCtrl.dispose();
    _guardianCtrl.dispose();
    _personalityCtrl.dispose();
    _specialNotesCtrl.dispose();
    _hospitalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(Pet pet) async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final photo = _photo == null
          ? null
          : PetPhotoUpload(
              bytes: await _photo!.readAsBytes(),
              filename: _photo!.name,
            );
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'species': _species,
        if (_birthDateUnknown)
          'birthDateUnknown': true
        else if (_compactText(_birthCtrl.text) != null)
          'birthDate': _compactText(_birthCtrl.text),
        'accentColor': pet.accentColor,
        'bgLight': pet.bgLight,
        if (_compactText(_breedCtrl.text) != null)
          'breed': _compactText(_breedCtrl.text),
        if (_compactText(_adoptionCtrl.text) != null)
          'adoptionDate': _compactText(_adoptionCtrl.text),
        if (_gender != null) 'gender': _gender,
        if (pet.weight != null) 'weight': pet.weight,
        if (pet.animalRegistrationNumber != null)
          'animalRegistrationNumber': pet.animalRegistrationNumber,
        if (_gender == 'male')
          'neutered': _neutered ?? false
        else if (pet.neutered != null)
          'neutered': pet.neutered,
        if (_selectedDiseases.isNotEmpty)
          'diseases': _selectedDiseases.join(', '),
        if (_compactText(_specialNotesCtrl.text) != null)
          'specialNotes': _compactText(_specialNotesCtrl.text),
        if (_compactText(_guardianCtrl.text) != null)
          'guardianNickname': _compactText(_guardianCtrl.text),
        if (_specialStatus != null) 'specialStatus': _specialStatus,
        if (_compactText(_personalityCtrl.text) != null)
          'personality': _compactText(_personalityCtrl.text),
        if (_compactText(_hospitalCtrl.text) != null)
          'primaryHospitalName': _compactText(_hospitalCtrl.text),
      };

      await ref
          .read(petProvider.notifier)
          .updatePet(widget.petId, body, photo: photo);
      if (!mounted) return;
      setState(() => _isLoading = false);
      await _showSavedDialog();
      if (!mounted) return;
      context.go('/pet/${widget.petId}');
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSavedDialog() {
    final petName = _nameCtrl.text.trim();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PetConfirmDialog(
        title: '수정 완료',
        body: '$petName의 정보가 수정되었습니다.',
        actions: [
          PetConfirmDialogAction(
            label: '확인',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() => _photo = photo);
    }
  }

  Future<void> _goBack() async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    final petExists = ref
        .read(petProvider)
        .pets
        .any((pet) => pet.id == widget.petId);
    context.go(petExists ? '/pet/${widget.petId}' : '/my');
  }

  void _resetHydration() {
    _nameCtrl.clear();
    _breedCtrl.clear();
    _birthCtrl.clear();
    _adoptionCtrl.clear();
    _guardianCtrl.clear();
    _personalityCtrl.clear();
    _specialNotesCtrl.clear();
    _hospitalCtrl.clear();
    _species = 'dog';
    _gender = null;
    _neutered = null;
    _birthDateUnknown = false;
    _specialStatus = null;
    _selectedDiseases.clear();
    _photo = null;
    _error = null;
    _hydratedPetId = null;
  }

  void _hydratePet(Pet pet) {
    if (!mounted || widget.petId != pet.id || _hydratedPetId == pet.id) {
      return;
    }
    setState(() {
      _nameCtrl.text = pet.name;
      _breedCtrl.text = pet.breed ?? '';
      _birthCtrl.text = pet.birthDate ?? '';
      _adoptionCtrl.text = pet.adoptionDate ?? '';
      _guardianCtrl.text = pet.guardianNickname ?? '';
      _personalityCtrl.text = pet.personality ?? '';
      _specialNotesCtrl.text = pet.specialNotes ?? '';
      _hospitalCtrl.text = pet.primaryHospitalName ?? '';
      _species = pet.species;
      _gender = pet.gender;
      _neutered = pet.neutered;
      _birthDateUnknown = pet.birthDate == null;
      _specialStatus = pet.specialStatus;
      _selectedDiseases
        ..clear()
        ..addAll(_diseaseValuesFromText(pet.diseases));
      _hydratedPetId = pet.id;
    });
  }

  void _selectSpecies(String species) {
    setState(() {
      _species = species;
      if (!isBreedOptionForSpecies(species, _breedCtrl.text)) {
        _breedCtrl.clear();
      }
    });
  }

  void _selectGender(String gender) {
    setState(() {
      _gender = _gender == gender ? null : gender;
    });
  }

  Future<void> _selectBreed() async {
    final selected = await showAppPickerSheet<String>(
      context,
      title: '품종/하위종',
      searchable: true,
      options: [
        for (final breed in breedOptionsForSpecies(_species))
          AppSelectOption(value: breed, label: breed),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() => _breedCtrl.text = selected);
  }

  Future<void> _selectDiseases() async {
    final selected = await showAppMultiPickerSheet<String>(
      context,
      title: '질병',
      selectedValues: _selectedDiseases,
      options: [
        for (final disease in kDiseaseOptions)
          AppSelectOption(value: disease, label: disease),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedDiseases
        ..clear()
        ..addAll(selected);
    });
  }

  void _markBirthDateUnknown() {
    setState(() {
      _birthCtrl.clear();
      _birthDateUnknown = true;
    });
  }

  Future<void> _selectDate({
    required TextEditingController controller,
    required DateTime firstDate,
    required DateTime lastDate,
    VoidCallback? onDateSelected,
  }) async {
    final now = DateTime.now();
    final initialDate = clampCalendarDate(
      DateTime.tryParse(controller.text) ?? now,
      firstDate,
      lastDate,
    );
    final date = await showRecordDatePickerSheet(
      context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return;
    setState(() {
      controller.text =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      onDateSelected?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petProvider);
    final pet = state.pets.where((pet) => pet.id == widget.petId).firstOrNull;
    if (state.isLoading) {
      return _buildStatusScaffold(const CircularProgressIndicator());
    }
    if (pet == null) {
      return _buildStatusScaffold(const AppText('반려동물을 찾을 수 없습니다'));
    }
    if (_hydratedPetId != pet.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydratePet(pet));
      return _buildStatusScaffold(const CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildHeader(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('사진', fontWeight: FontWeight.bold),
                  const SizedBox(height: 8),
                  _PhotoPickerTile(photo: _photo, onTap: _pickPhoto),
                  const SizedBox(height: 16),
                  _IdentitySection(
                    nameCtrl: _nameCtrl,
                    breedCtrl: _breedCtrl,
                    species: _species,
                    onSpeciesSelected: _selectSpecies,
                    onBreedTap: _selectBreed,
                  ),
                  const SizedBox(height: 14),
                  _ProfileSection(
                    pet: pet,
                    birthCtrl: _birthCtrl,
                    adoptionCtrl: _adoptionCtrl,
                    gender: _gender,
                    neutered: _displayNeutered(pet),
                    neuteredEnabled: _gender == 'male',
                    onBirthTap: () => _selectDate(
                      controller: _birthCtrl,
                      firstDate: calendarFirstDate,
                      lastDate: birthdayCalendarLastDate(DateTime.now()),
                      onDateSelected: () => _birthDateUnknown = false,
                    ),
                    onAdoptionTap: () => _selectDate(
                      controller: _adoptionCtrl,
                      firstDate: calendarFirstDate,
                      lastDate: DateTime.now(),
                    ),
                    onBirthUnknownTap: _markBirthDateUnknown,
                    onGenderSelected: _selectGender,
                    onNeuteredSelected: (value) =>
                        setState(() => _neutered = value),
                  ),
                  const SizedBox(height: 14),
                  _ExtraSection(
                    specialStatus: _specialStatus,
                    selectedDiseases: _selectedDiseases,
                    personalityCtrl: _personalityCtrl,
                    guardianCtrl: _guardianCtrl,
                    specialNotesCtrl: _specialNotesCtrl,
                    hospitalCtrl: _hospitalCtrl,
                    onSpecialStatusSelected: (value) => setState(
                      () => _specialStatus == value
                          ? _specialStatus = null
                          : _specialStatus = value,
                    ),
                    onDiseasesTap: _selectDiseases,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AppText(_error!, color: AppColors.danger),
                  ],
                ],
              ),
            ),
          ),
          _BottomSubmitButton(isLoading: _isLoading, onTap: () => _save(pet)),
        ],
      ),
    );
  }

  bool? _displayNeutered(Pet pet) {
    if (_gender == 'male') {
      return _neutered ?? false;
    }
    return pet.neutered;
  }

  Scaffold _buildStatusScaffold(Widget child) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildHeader(),
      body: Center(child: child),
    );
  }

  AppHeader _buildHeader() {
    return AppHeader(
      title: '반려동물 수정',
      showBackButton: true,
      centerTitle: true,
      onBack: _goBack,
    );
  }
}

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
          const AppText('종', fontWeight: FontWeight.bold),
          const SizedBox(height: 8),
          GridView.builder(
            key: const Key('pet-edit-species-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kPetSpecies.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 48,
            ),
            itemBuilder: (context, index) {
              final item = kPetSpecies[index];
              return PetChoiceButton(
                label: item.label,
                selected: species == item.id,
                onTap: () => onSpeciesSelected(item.id),
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
  final Pet pet;
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
    required this.pet,
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
  final bool isLoading;
  final VoidCallback onTap;

  const _BottomSubmitButton({required this.isLoading, required this.onTap});

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
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.text,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const AppText(
                    '수정 완료',
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPickerTile extends StatelessWidget {
  final XFile? photo;
  final VoidCallback onTap;

  const _PhotoPickerTile({required this.photo, required this.onTap});

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
              child: const Icon(
                Icons.add_a_photo_rounded,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AppText(
                photo?.name ?? '대표 사진 선택',
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
