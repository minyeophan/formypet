import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/keyboard_utils.dart';
import '../../providers/pet_provider.dart';
import '../../core/pet_colors.dart';
import '../../core/record_utils.dart';
import '../../widgets/app_text.dart';

enum PetEntryMode { firstPet, additionalPet }

class OnboardingScreen extends ConsumerStatefulWidget {
  final PetEntryMode mode;

  const OnboardingScreen({super.key, this.mode = PetEntryMode.firstPet});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
  String _species = 'dog';
  String? _gender;
  XFile? _photo;
  int _colorIndex = 0;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _birthCtrl.text.trim().isEmpty) {
      setState(() => _error = '이름과 생년월일을 입력해주세요');
      return;
    }
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
      await ref.read(petProvider.notifier).addPet({
        'name': _nameCtrl.text.trim(),
        'species': _species,
        'birthDate': _birthCtrl.text.trim(),
        'accentColor': color.accentHex,
        'bgLight': color.bgLightHex,
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

  Future<void> _pickPhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() => _photo = photo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('반려동물 등록')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('대표 사진 (선택)', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            _PhotoPickerTile(photo: _photo, onTap: _pickPhoto),
            const SizedBox(height: 20),
            const AppText('이름', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: '반려동물 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const AppText('종류', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: kSpeciesList.map((s) {
                final selected = _species == s;
                return ChoiceChip(
                  label: AppText(speciesLabel(s)),
                  selected: selected,
                  onSelected: (_) => setState(() => _species = s),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const AppText('생년월일', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            TextField(
              controller: _birthCtrl,
              decoration: const InputDecoration(
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  _birthCtrl.text =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                }
              },
              readOnly: true,
            ),
            const SizedBox(height: 20),
            const AppText('성별 (선택)', fontWeight: FontWeight.bold),
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
            const SizedBox(height: 20),
            const AppText('색상', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            Row(
              children: List.generate(kPetColors.length, (i) {
                final color = kPetColors[i];
                return GestureDetector(
                  onTap: () => setState(() => _colorIndex = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.accent,
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const AppText('등록하기', fontWeight: FontWeight.bold),
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
