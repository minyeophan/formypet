import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/preparing_toast.dart';
import 'my_support_widgets.dart';

class MyInquiryScreen extends StatefulWidget {
  const MyInquiryScreen({super.key});

  @override
  State<MyInquiryScreen> createState() => _MyInquiryScreenState();
}

class _MyInquiryScreenState extends State<MyInquiryScreen> {
  static const _types = ['계정/로그인', '기록/루틴', '커뮤니티', '오류 신고', '기타'];

  String _selectedType = _types.first;
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
          children: [
            const AppText(
              '문의 내용을 남기면 확인 후 앱 알림 또는 이메일로 답변을 안내합니다.',
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
                      initialValue: _selectedType,
                      items: [
                        for (final type in _types)
                          DropdownMenuItem(value: type, child: Text(type)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedType = value);
                      },
                      decoration: _inputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel(
                    label: '제목',
                    child: TextField(
                      controller: _titleController,
                      decoration: _inputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel(
                    label: '문의 내용',
                    child: TextField(
                      key: const Key('my-inquiry-body-field'),
                      controller: _bodyController,
                      minLines: 5,
                      maxLines: 7,
                      decoration: _inputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const AppText(
                    '개인정보나 민감한 건강 정보는 꼭 필요한 경우에만 입력해 주세요.',
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => showPreparingToast(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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
      fillColor: AppColors.surface,
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
