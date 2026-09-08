import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../providers/pet_provider.dart';
import '../../providers/wallet_expense_provider.dart';
import '../../providers/wallet_query_provider.dart';
import '../../widgets/app_header.dart';
import 'expense_form.dart';
import 'wallet_refresh_notice.dart';

class ExpenseAddScreen extends ConsumerStatefulWidget {
  const ExpenseAddScreen({super.key});

  @override
  ConsumerState<ExpenseAddScreen> createState() => _ExpenseAddScreenState();
}

class _ExpenseAddScreenState extends ConsumerState<ExpenseAddScreen> {
  var _submitting = false;
  String? _errorText;
  int? _session;
  String? _selectedPetId;
  bool _initializedPet = false;
  String? _initialWalletPetId;

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petProvider);
    final session = ref.watch(walletExpenseProvider.select((s) => s.session));
    if (_session != session) {
      _session = session;
      _initialWalletPetId = ref.read(walletQueryProvider).petId;
      _selectedPetId = null;
      _initializedPet = false;
      _submitting = false;
      _errorText = null;
    }
    if (!_initializedPet && !pets.isLoading) {
      _selectedPetId = pets.pets.any((pet) => pet.id == _initialWalletPetId)
          ? _initialWalletPetId
          : _initialWalletPetId == null && pets.pets.length == 1
          ? pets.pets.single.id
          : null;
      _initializedPet = true;
    }
    final selectedPet = pets.pets
        .where((pet) => pet.id == _selectedPetId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            AppFormHeader(title: '지출 추가', onBack: _goBack),
            Expanded(
              child: ExpenseFormBody(
                key: ValueKey(session),
                mode: ExpenseFormMode.add,
                initialData: ExpenseFormData.now(),
                petName: selectedPet?.name,
                validTarget: !pets.isLoading && selectedPet != null,
                petSelector: pets.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : pets.pets.isEmpty
                    ? Text(
                        pets.dataErrorText == null
                            ? '반려동물을 등록해 주세요'
                            : '반려동물 정보를 불러오지 못했어요.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selectedPet == null)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Text('지출을 기록할 반려동물을 선택해 주세요'),
                            ),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final pet in pets.pets)
                                ChoiceChip(
                                  key: Key('expense-pet-${pet.id}'),
                                  label: Text(pet.name),
                                  selected: selectedPet?.id == pet.id,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: AppColors.white,
                                  labelStyle: TextStyle(
                                    color: selectedPet?.id == pet.id
                                        ? AppColors.white
                                        : AppColors.text,
                                  ),
                                  onSelected: _submitting
                                      ? null
                                      : (_) => setState(() {
                                          _selectedPetId = pet.id;
                                          _errorText = null;
                                        }),
                                ),
                            ],
                          ),
                        ],
                      ),
                submitting: _submitting,
                errorText: _errorText,
                onSubmit: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(ExpenseFormData data) async {
    if (_submitting) {
      return;
    }
    final pets = ref.read(petProvider);
    final selectedPet = pets.pets
        .where((pet) => pet.id == _selectedPetId)
        .firstOrNull;
    if (pets.isLoading ||
        selectedPet == null ||
        _session != ref.read(walletExpenseProvider).session) {
      setState(() => _errorText = '지출을 기록할 반려동물을 선택해 주세요.');
      return;
    }
    final session = ref.read(walletExpenseProvider).session;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(walletExpenseProvider.notifier)
          .createExpense(selectedPet.id, data.toWalletExpenseBody());
      if (!mounted || ref.read(walletExpenseProvider).session != session) {
        return;
      }
      showWalletRefreshWarning(context, ref.read(walletExpenseProvider));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/wallet');
      }
    } catch (_) {
      if (!mounted || ref.read(walletExpenseProvider).session != session) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorText = '지출을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _goBack() async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/wallet');
  }
}
