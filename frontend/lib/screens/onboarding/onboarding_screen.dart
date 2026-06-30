import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../core/calendar_ranges.dart';
import '../../core/keyboard_utils.dart';
import '../../core/pet_taxonomy.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_picker_sheet.dart';
import '../../widgets/app_text.dart';
import '../../widgets/pet_form_fields.dart';
import '../../widgets/record_inputs/record_inputs.dart';

enum PetEntryMode { firstPet, additionalPet }

class OnboardingScreen extends ConsumerStatefulWidget {
  final PetEntryMode mode;

  const OnboardingScreen({super.key, this.mode = PetEntryMode.firstPet});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
  String _species = 'dog';
  String? _gender;
  bool _birthDateUnknown = true;
  XFile? _photo;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = '이름을 입력해 주세요');
      return;
    }
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
      await ref.read(petProvider.notifier).addPet({
        'name': _nameCtrl.text.trim(),
        'species': _species,
        if (_compactText(_breedCtrl.text) != null)
          'breed': _compactText(_breedCtrl.text),
        if (!_birthDateUnknown && _compactText(_birthCtrl.text) != null)
          'birthDate': _compactText(_birthCtrl.text),
        if (_gender != null) 'gender': _gender,
      }, photo: photo);
      if (mounted && widget.mode == PetEntryMode.additionalPet) {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectSpecies(String species) {
    setState(() {
      _species = species;
      if (!isBreedOptionForSpecies(species, _breedCtrl.text)) {
        _breedCtrl.clear();
      }
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

  void _markBirthDateUnknown() {
    setState(() {
      _birthCtrl.clear();
      _birthDateUnknown = true;
    });
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final lastDate = birthdayCalendarLastDate(now);
    final date = await showRecordDatePickerSheet(
      context,
      initialDate: clampCalendarDate(
        DateTime.tryParse(_birthCtrl.text) ?? now,
        calendarFirstDate,
        lastDate,
      ),
      firstDate: calendarFirstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return;
    setState(() {
      _birthDateUnknown = false;
      _birthCtrl.text =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    });
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
    context.go('/my');
  }

  @override
  Widget build(BuildContext context) {
    final breed = _compactText(_breedCtrl.text);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '반려동물 등록',
        centerTitle: true,
        showBackButton: widget.mode == PetEntryMode.additionalPet,
        onBack: widget.mode == PetEntryMode.additionalPet ? _goBack : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('대표 사진 (선택)', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            _PhotoPickerTile(photo: _photo, onTap: _pickPhoto),
            const SizedBox(height: 18),
            PetTextField(
              label: '이름',
              controller: _nameCtrl,
              hintText: '반려동물 이름',
            ),
            const SizedBox(height: 18),
            const AppText('종류', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final species in kPetSpecies)
                  PetChoiceButton(
                    label: species.label,
                    selected: _species == species.id,
                    onTap: () => _selectSpecies(species.id),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            PetPickerField(
              label: '품종/하위종',
              value: breed ?? '선택',
              isPlaceholder: breed == null,
              onTap: _selectBreed,
            ),
            const SizedBox(height: 18),
            PetDateField(
              label: '생년월일',
              value: _birthCtrl.text,
              placeholder: 'YYYY-MM-DD',
              onTap: _selectBirthDate,
              trailing: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _markBirthDateUnknown,
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
            const SizedBox(height: 18),
            const AppText('성별 (선택)', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PetChoiceButton(
                  label: '남아',
                  selected: _gender == 'male',
                  onTap: () => setState(
                    () => _gender = _gender == 'male' ? null : 'male',
                  ),
                ),
                PetChoiceButton(
                  label: '여아',
                  selected: _gender == 'female',
                  onTap: () => setState(
                    () => _gender = _gender == 'female' ? null : 'female',
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AppText(_error!, color: AppColors.danger),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.text,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppText(
                        '등록하기',
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

String? _compactText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
