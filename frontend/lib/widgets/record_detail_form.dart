import 'package:flutter/material.dart';
import 'app_text.dart';

class RecordDetailForm extends StatelessWidget {
  final String typeId;
  final Map<String, dynamic> detail;
  final void Function(Map<String, dynamic>) onChanged;

  const RecordDetailForm({
    super.key,
    required this.typeId,
    required this.detail,
    required this.onChanged,
  });

  void _set(String key, dynamic value) {
    final updated = Map<String, dynamic>.from(detail);
    updated[key] = value;
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return switch (typeId) {
      'meal' => _MealForm(detail: detail, onSet: _set),
      'water' => _SimpleAmountForm(detail: detail, onSet: _set, unit: 'ml'),
      'weight' => _WeightForm(detail: detail, onSet: _set),
      'walk' => _WalkForm(detail: detail, onSet: _set),
      'medicine' => _MedicineForm(detail: detail, onSet: _set),
      'vet' => _VetForm(detail: detail, onSet: _set),
      'poop' => _PoopForm(detail: detail, onSet: _set),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String? initial;
  final void Function(String) onChanged;
  final TextInputType keyboardType;

  const _Field({
    required this.label,
    this.initial,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: TextEditingController(text: initial),
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        keyboardType: keyboardType,
        onChanged: onChanged,
      ),
    );
  }
}

class _MealForm extends StatelessWidget {
  final Map<String, dynamic> detail;
  final void Function(String, dynamic) onSet;

  const _MealForm({required this.detail, required this.onSet});

  @override
  Widget build(BuildContext context) {
    final mode = detail['consumeMode'] ?? 'direct';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Field(
          label: '음식 이름',
          initial: detail['foodName']?.toString(),
          onChanged: (v) => onSet('foodName', v),
        ),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const AppText('직접 입력'),
                selected: mode == 'direct',
                onSelected: (_) => onSet('consumeMode', 'direct'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const AppText('비율(%)'),
                selected: mode == 'percent',
                onSelected: (_) => onSet('consumeMode', 'percent'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (mode == 'direct')
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: '섭취량',
                  initial: detail['amount']?.toString(),
                  onChanged: (v) => onSet('amount', v),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  label: '단위',
                  initial: detail['unit']?.toString() ?? 'g',
                  onChanged: (v) => onSet('unit', v),
                ),
              ),
            ],
          )
        else
          _Field(
            label: '섭취율(%)',
            initial: detail['consumePercent']?.toString(),
            onChanged: (v) => onSet('consumePercent', v),
            keyboardType: TextInputType.number,
          ),
      ],
    );
  }
}

class _SimpleAmountForm extends StatelessWidget {
  final Map<String, dynamic> detail;
  final void Function(String, dynamic) onSet;
  final String unit;

  const _SimpleAmountForm(
      {required this.detail, required this.onSet, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Field(
            label: '양',
            initial: detail['amount']?.toString(),
            onChanged: (v) => onSet('amount', v),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Field(
            label: '단위',
            initial: detail['unit']?.toString() ?? unit,
            onChanged: (v) => onSet('unit', v),
          ),
        ),
      ],
    );
  }
}

class _WeightForm extends StatelessWidget {
  final Map<String, dynamic> detail;
  final void Function(String, dynamic) onSet;

  const _WeightForm({required this.detail, required this.onSet});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Field(
            label: '체중',
            initial: detail['value']?.toString(),
            onChanged: (v) => onSet('value', v),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Field(
            label: '단위',
            initial: detail['unit']?.toString() ?? 'kg',
            onChanged: (v) => onSet('unit', v),
          ),
        ),
      ],
    );
  }
}

class _WalkForm extends StatelessWidget {
  final Map<String, dynamic> detail;
  final void Function(String, dynamic) onSet;

  const _WalkForm({required this.detail, required this.onSet});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(
          label: '산책 시간(분)',
          initial: detail['duration']?.toString(),
          onChanged: (v) => onSet('duration', v),
          keyboardType: TextInputType.number,
        ),
        _Field(
          label: '거리(km)',
          initial: detail['distance']?.toString(),
          onChanged: (v) => onSet('distance', v),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}

class _MedicineForm extends StatelessWidget {
  final Map<String, dynamic> detail;
  final void Function(String, dynamic) onSet;

  const _MedicineForm({required this.detail, required this.onSet});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(
          label: '약 이름',
          initial: detail['medicineName']?.toString(),
          onChanged: (v) => onSet('medicineName', v),
        ),
        Row(
          children: [
            Expanded(
              child: _Field(
                label: '용량',
                initial: detail['dosage']?.toString(),
                onChanged: (v) => onSet('dosage', v),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Field(
                label: '단위',
                initial: detail['unit']?.toString() ?? 'mg',
                onChanged: (v) => onSet('unit', v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VetForm extends StatelessWidget {
  final Map<String, dynamic> detail;
  final void Function(String, dynamic) onSet;

  const _VetForm({required this.detail, required this.onSet});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(
          label: '병원 이름',
          initial: detail['clinicName']?.toString(),
          onChanged: (v) => onSet('clinicName', v),
        ),
        _Field(
          label: '진단',
          initial: detail['diagnosis']?.toString(),
          onChanged: (v) => onSet('diagnosis', v),
        ),
        _Field(
          label: '진료비(원)',
          initial: detail['vetCost']?.toString(),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            if (parsed != null) onSet('vetCost', parsed);
          },
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}

class _PoopForm extends StatelessWidget {
  final Map<String, dynamic> detail;
  final void Function(String, dynamic) onSet;

  const _PoopForm({required this.detail, required this.onSet});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(
          label: '변 상태',
          initial: detail['consistency']?.toString(),
          onChanged: (v) => onSet('consistency', v),
        ),
        _Field(
          label: '색상',
          initial: detail['color']?.toString(),
          onChanged: (v) => onSet('color', v),
        ),
        Row(
          children: [
            const AppText('혈변 여부'),
            const SizedBox(width: 8),
            Switch(
              value: detail['hasBlood'] == true,
              onChanged: (v) => onSet('hasBlood', v),
            ),
          ],
        ),
      ],
    );
  }
}
