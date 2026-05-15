import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/pet_provider.dart';
import '../../core/pet_colors.dart';
import '../../core/record_utils.dart';
import '../../widgets/app_text.dart';

class PetEditScreen extends ConsumerStatefulWidget {
  final String petId;
  const PetEditScreen({super.key, required this.petId});

  @override
  ConsumerState<PetEditScreen> createState() => _PetEditScreenState();
}

class _PetEditScreenState extends ConsumerState<PetEditScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _birthCtrl;
  late String _species;
  late String? _gender;
  late int _colorIndex;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final pet = ref.read(petProvider).pets.firstWhere((p) => p.id == widget.petId);
    _nameCtrl = TextEditingController(text: pet.name);
    _birthCtrl = TextEditingController(text: pet.birthDate);
    _species = pet.species;
    _gender = pet.gender;
    _colorIndex = kPetColors
        .indexWhere((c) => c.accentHex.toLowerCase() == pet.accentColor.toLowerCase());
    if (_colorIndex == -1) _colorIndex = 0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final color = kPetColors[_colorIndex];
      await ref.read(petProvider.notifier).updatePet(widget.petId, {
        'name': _nameCtrl.text.trim(),
        'species': _species,
        'birthDate': _birthCtrl.text.trim(),
        'accentColor': color.accentHex,
        'bgLight': color.bgLightHex,
        if (_gender != null) 'gender': _gender,
      });
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('반려동물 수정'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const AppText('저장', color: Colors.blue,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: '이름', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const AppText('종류', fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: kSpeciesList.map((s) => ChoiceChip(
                    label: AppText(speciesLabel(s)),
                    selected: _species == s,
                    onSelected: (_) => setState(() => _species = s),
                  )).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _birthCtrl,
              decoration: const InputDecoration(
                  labelText: '생년월일 (YYYY-MM-DD)',
                  border: OutlineInputBorder()),
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_birthCtrl.text) ??
                      DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
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
                      () => _gender = _gender == 'male' ? null : 'male'),
                ),
                ChoiceChip(
                  label: const AppText('여아'),
                  selected: _gender == 'female',
                  onSelected: (_) => setState(
                      () => _gender = _gender == 'female' ? null : 'female'),
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
}
