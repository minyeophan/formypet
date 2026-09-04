import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_colors.dart';
import '../../core/calendar_ranges.dart';
import '../../core/keyboard_utils.dart';
import '../../core/pet_taxonomy.dart';
import '../../models/pet.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_picker_sheet.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_visual.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/pet_form_fields.dart';
import '../../widgets/record_inputs/record_inputs.dart';
import 'pet_confirm_dialog.dart';

part 'pet_profile_form_sections.dart';

class PetProfileForm extends ConsumerStatefulWidget {
  final String? petId;
  final bool firstPet;
  const PetProfileForm({super.key, this.petId, this.firstPet = false});

  @override
  ConsumerState<PetProfileForm> createState() => _PetProfileFormState();
}

class _PetProfileFormState extends ConsumerState<PetProfileForm> {
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
  Uint8List? _photoBytes;
  bool _isLoading = false;
  String? _error;
  String? _hydratedPetId;
  bool _extraExpanded = false;
  bool _allowPop = false;
  bool _confirmingExit = false;
  String? _initialSnapshot;
  String? _createdPetId;
  bool _photoSaveFailed = false;
  bool get _editing => widget.petId != null;
  List<TextEditingController> get _controllers => [
    _nameCtrl,
    _breedCtrl,
    _birthCtrl,
    _adoptionCtrl,
    _guardianCtrl,
    _personalityCtrl,
    _specialNotesCtrl,
    _hospitalCtrl,
  ];
  String get _snapshot => jsonEncode([
    for (final c in _controllers) c.text,
    _species,
    _gender,
    _neutered,
    _specialStatus,
    _selectedDiseases.join(','),
    _photo?.path,
  ]);

  @override
  void initState() {
    super.initState();
    _initialSnapshot = _snapshot;
    for (final c in _controllers) {
      c.addListener(_onInput);
    }
  }

  void _onInput() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PetProfileForm oldWidget) {
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

  Future<void> _save(Pet? pet, {bool skipPhoto = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = '반려동물 이름을 입력해 주세요.';
        _isLoading = false;
      });
      return;
    }
    if (name.length > 50) {
      setState(() {
        _error = '반려동물 이름은 50자 이하로 입력해 주세요.';
        _isLoading = false;
      });
      return;
    }

    for (final field in [
      (_guardianCtrl, 30, '보호자 호칭'),
      (_hospitalCtrl, 100, '주치의·병원'),
    ]) {
      if (field.$1.text.trim().length > field.$2) {
        setState(() {
          _error = '${field.$3}은 ${field.$2}자 이하로 입력해 주세요.';
          _isLoading = false;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final photo = _photo == null || skipPhoto
          ? null
          : PetPhotoUpload(
              bytes: await _photo!.readAsBytes(),
              filename: _photo!.name,
            );
      final body = <String, dynamic>{
        'name': name,
        'species': _species,
        if ((_editing || _createdPetId != null) &&
            (_birthDateUnknown || _birthCtrl.text.isEmpty))
          'birthDateUnknown': true
        else if (_compactText(_birthCtrl.text) != null)
          'birthDate': _compactText(_birthCtrl.text),
        if (pet != null) 'accentColor': pet.accentColor,
        if (pet != null) 'bgLight': pet.bgLight,
        if (_compactText(_breedCtrl.text) != null)
          'breed': _compactText(_breedCtrl.text),
        if (_compactText(_adoptionCtrl.text) != null)
          'adoptionDate': _compactText(_adoptionCtrl.text),
        if (_gender != null) 'gender': _gender,
        if (pet?.weight != null) 'weight': pet!.weight,
        if (pet?.animalRegistrationNumber != null)
          'animalRegistrationNumber': pet!.animalRegistrationNumber,
        if (_neutered != null) 'neutered': _neutered,
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

      final notifier = ref.read(petProvider.notifier);
      final id = widget.petId ?? _createdPetId;
      if (id != null) {
        await notifier.updatePet(id, body, photo: photo);
      } else {
        await notifier.addPet(body, photo: photo);
        if (!mounted) return;
        _createdPetId = ref.read(petProvider).activePetId;
      }
      if (!mounted) return;
      _initialSnapshot = _snapshot;
      setState(() => _isLoading = false);
      if (_editing) await _showSavedDialog();
      if (!mounted) return;
      GoRouter.maybeOf(context)?.go(
        widget.firstPet ? '/home' : '/pet/${widget.petId ?? _createdPetId}',
      );
    } on PetPhotoSaveException catch (e) {
      if (mounted) {
        setState(() {
          _createdPetId = e.petId;
          _photoSaveFailed = true;
          _error = e.toString();
        });
      }
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
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (mounted) {
        setState(() {
          _photo = photo;
          _photoBytes = bytes;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 불러오지 못했어요. 사진 접근 권한을 확인해 주세요.');
    }
  }

  Future<void> _goBack() async {
    if (_isLoading || _confirmingExit || widget.firstPet) return;
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    if (_snapshot != _initialSnapshot) {
      _confirmingExit = true;
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => PetConfirmDialog(
          title: '입력을 그만둘까요?',
          body: _photoSaveFailed
              ? '반려동물 정보는 이미 저장됐어요. 아직 올리지 못한 사진과 이후 변경 사항은 반영되지 않아요.'
              : '저장하지 않은 변경 사항은 사라져요.',
          actions: [
            PetConfirmDialogAction(
              label: '계속 입력',
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            PetConfirmDialogAction(
              label: '나가기',
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      );
      _confirmingExit = false;
      if (!mounted || leave != true) return;
    }
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
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
    _photoBytes = null;
    _photoSaveFailed = false;
    _error = null;
    _hydratedPetId = null;
    _createdPetId = null;
    _extraExpanded = false;
    _initialSnapshot = _snapshot;
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
      _extraExpanded = [
        pet.specialStatus,
        pet.diseases,
        pet.personality,
        pet.guardianNickname,
        pet.specialNotes,
        pet.primaryHospitalName,
      ].any((v) => v != null && v.trim().isNotEmpty);
      _initialSnapshot = _snapshot;
    });
  }

  void _selectSpecies(String species) {
    if (_species == species) return;
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
        const AppSelectOption(value: '', label: '선택 해제'),
        if (_breedCtrl.text.isNotEmpty &&
            !isBreedOptionForSpecies(_species, _breedCtrl.text))
          AppSelectOption(value: _breedCtrl.text, label: _breedCtrl.text),
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
        for (final disease in {...kDiseaseOptions, ..._selectedDiseases})
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
    if (_editing && state.isLoading && _hydratedPetId == null) {
      return _buildStatusScaffold(const CircularProgressIndicator());
    }
    if (_editing && pet == null) {
      return _buildStatusScaffold(const AppText('반려동물을 찾을 수 없습니다'));
    }
    if (pet != null && _hydratedPetId != pet.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydratePet(pet));
      return _buildStatusScaffold(const CircularProgressIndicator());
    }

    return PopScope(
      canPop:
          _allowPop ||
          (!widget.firstPet && !_isLoading && _snapshot == _initialSnapshot),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildHeader(),
        body: Column(
          children: [
            Expanded(
              child: AbsorbPointer(
                absorbing: _isLoading,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        '이름·동물 종류는 필수이며, 나머지는 선택이에요.',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      const AppText('사진 (선택)', fontWeight: FontWeight.bold),
                      const SizedBox(height: 8),
                      _PhotoPickerTile(
                        photo: _photo,
                        bytes: _photoBytes,
                        existingUrl: pet?.profileImageUrl,
                        onTap: _pickPhoto,
                      ),
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
                        birthCtrl: _birthCtrl,
                        adoptionCtrl: _adoptionCtrl,
                        gender: _gender,
                        neutered: _neutered,
                        neuteredEnabled: true,
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
                        onNeuteredSelected: (value) => setState(
                          () => _neutered = _neutered == value ? null : value,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () =>
                            setState(() => _extraExpanded = !_extraExpanded),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: AppText(
                                '추가 정보 (선택)',
                                color: AppColors.primary,
                              ),
                            ),
                            Icon(
                              _extraExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                          ],
                        ),
                      ),
                      if (_extraExpanded)
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
                    ],
                  ),
                ),
              ),
            ),
            _BottomSubmitButton(
              onSkipPhoto: _photoSaveFailed
                  ? () => _save(pet, skipPhoto: true)
                  : null,
              label: _editing ? '저장' : '등록',
              error: _error,
              isLoading: _isLoading,
              onTap: () => _save(pet),
            ),
          ],
        ),
      ),
    );
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
      title: _editing ? '반려동물 수정' : '반려동물 등록',
      showBackButton: !widget.firstPet,
      centerTitle: true,
      onBack: widget.firstPet ? null : _goBack,
    );
  }
}
