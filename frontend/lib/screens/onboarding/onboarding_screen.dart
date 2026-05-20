import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final color = kPetColors[_colorIndex];
      await ref.read(petProvider.notifier).addPet({
        'name': _nameCtrl.text.trim(),
        'species': _species,
        'birthDate': _birthCtrl.text.trim(),
        'accentColor': color.accentHex,
        'bgLight': color.bgLightHex,
        if (_gender != null) 'gender': _gender,
      });
      if (mounted && widget.mode == PetEntryMode.additionalPet) {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
