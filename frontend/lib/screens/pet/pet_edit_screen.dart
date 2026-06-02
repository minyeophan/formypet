import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/calendar_ranges.dart';
import '../../core/keyboard_utils.dart';
import '../../providers/pet_provider.dart';
import '../../core/pet_colors.dart';
import '../../core/record_utils.dart';
import '../../models/pet.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';

class PetEditScreen extends ConsumerStatefulWidget {
  final String petId;
  const PetEditScreen({super.key, required this.petId});

  @override
  ConsumerState<PetEditScreen> createState() => _PetEditScreenState();
}

class _PetEditScreenState extends ConsumerState<PetEditScreen> {
  final _nameCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
  String _species = 'dog';
  String? _gender;
  XFile? _photo;
  int _colorIndex = 0;
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
    _birthCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final color = kPetColors[_colorIndex];
      final photo = _photo == null
          ? null
          : PetPhotoUpload(
              bytes: await _photo!.readAsBytes(),
              filename: _photo!.name,
            );
      await ref.read(petProvider.notifier).updatePet(widget.petId, {
        'name': _nameCtrl.text.trim(),
        'species': _species,
        'birthDate': _birthCtrl.text.trim(),
        'accentColor': color.accentHex,
        'bgLight': color.bgLightHex,
        if (_gender != null) 'gender': _gender,
      }, photo: photo);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/pet/${widget.petId}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    _birthCtrl.clear();
    _species = 'dog';
    _gender = null;
    _photo = null;
    _colorIndex = 0;
    _error = null;
    _hydratedPetId = null;
  }

  void _hydratePet(Pet pet) {
    if (!mounted || widget.petId != pet.id || _hydratedPetId == pet.id) {
      return;
    }
    setState(() {
      _nameCtrl.text = pet.name;
      _birthCtrl.text = pet.birthDate;
      _species = pet.species;
      _gender = pet.gender;
      _colorIndex = kPetColors.indexWhere(
        (color) =>
            color.accentHex.toLowerCase() == pet.accentColor.toLowerCase(),
      );
      if (_colorIndex == -1) _colorIndex = 0;
      _hydratedPetId = pet.id;
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
      appBar: _buildHeader(showSave: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('대표 사진 (선택)', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            _PhotoPickerTile(photo: _photo, onTap: _pickPhoto),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const AppText('종류', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: kSpeciesList
                  .map(
                    (s) => ChoiceChip(
                      label: AppText(speciesLabel(s)),
                      selected: _species == s,
                      onSelected: (_) => setState(() => _species = s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _birthCtrl,
              decoration: const InputDecoration(
                labelText: '생년월일 (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: () async {
                final now = DateTime.now();
                final lastDate = birthdayCalendarLastDate(now);
                final date = await showDatePicker(
                  context: context,
                  initialDate: clampCalendarDate(
                    DateTime.tryParse(_birthCtrl.text) ?? now,
                    calendarFirstDate,
                    lastDate,
                  ),
                  firstDate: calendarFirstDate,
                  lastDate: lastDate,
                );
                if (date != null) {
                  _birthCtrl.text =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                }
              },
            ),
            const SizedBox(height: 16),
            const AppText('성별', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const AppText('남아'),
                  selected: _gender == 'male',
                  onSelected: (_) => setState(
                    () => _gender = _gender == 'male' ? null : 'male',
                  ),
                ),
                ChoiceChip(
                  label: const AppText('여아'),
                  selected: _gender == 'female',
                  onSelected: (_) => setState(
                    () => _gender = _gender == 'female' ? null : 'female',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const AppText('색상', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            Row(
              children: List.generate(kPetColors.length, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _colorIndex = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kPetColors[i].accent,
                      shape: BoxShape.circle,
                      border: _colorIndex == i
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AppText(_error!, color: Colors.red),
            ],
          ],
        ),
      ),
    );
  }

  Scaffold _buildStatusScaffold(Widget child) {
    return Scaffold(
      appBar: _buildHeader(),
      body: Center(child: child),
    );
  }

  AppHeader _buildHeader({bool showSave = false}) {
    return AppHeader(
      title: '반려동물 수정',
      showBackButton: true,
      centerTitle: true,
      onBack: _goBack,
      actions: showSave
          ? [
              SizedBox(
                width: kToolbarHeight,
                child: TextButton(
                  key: const Key('pet-edit-save-button'),
                  onPressed: _isLoading ? null : _save,
                  child: const AppText(
                    '저장',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          : null,
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
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_a_photo_rounded,
                color: Color(0xFF8A949E),
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
