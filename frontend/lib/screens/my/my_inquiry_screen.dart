import 'package:flutter/material.dart';
import '../../core/app_interaction_style.dart';

import '../../core/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'my_support_widgets.dart';

class MyInquiryScreen extends StatefulWidget {
  const MyInquiryScreen({super.key});

  @override
  State<MyInquiryScreen> createState() => _MyInquiryScreenState();
}

class _MyInquiryScreenState extends State<MyInquiryScreen> {
  static const _types = ['계정/로그인', '기록/루틴', '커뮤니티', '오류 신고', '기타'];

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '1대1 문의하기',
        showBackButton: true,
        centerTitle: true,
        onBack: () => goBackOrFallback(context, '/my'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const AppText(
              '1대1 문의는 준비중이에요. 현재 문의를 작성하거나 보낼 수 없어요.',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FieldLabel(
                    label: '문의 유형',
                    child: DropdownButtonFormField<String>(
                      initialValue: _types.first,
                      items: [
                        for (final type in _types)
                          DropdownMenuItem(value: type, child: Text(type)),
                      ],
                      onChanged: null,
                      decoration: _inputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel(
                    label: '제목',
                    child: TextField(
                      enabled: false,
                      controller: _titleController,
                      decoration: _inputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel(
                    label: '문의 내용',
                    child: TextField(
                      key: const Key('my-inquiry-body-field'),
                      enabled: false,
                      controller: _bodyController,
                      minLines: 5,
                      maxLines: 7,
                      decoration: _inputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                    child: const AppText(
                      '문의 접수',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppInteractionStyle.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF41B883)),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldLabel({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}
