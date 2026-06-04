import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/preparing_toast.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  final Future<XFile?> Function()? pickImage;

  const MyProfileScreen({super.key, this.pickImage});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  String? _hydratedEmail;
  Uint8List? _previewBytes;
  String? _error;

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file =
          await (widget.pickImage ??
              () => ImagePicker().pickImage(source: ImageSource.gallery))();
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 불러오지 못했어요.');
    }
  }

  Future<void> _goBack() async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/my/settings');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    if (profile != null && _hydratedEmail != profile.email) {
      _hydratedEmail = profile.email;
      _nickname.text = profile.nickname;
      _email.text = profile.email;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '내 프로필 편집',
        showBackButton: true,
        centerTitle: true,
        onBack: _goBack,
      ),
      body: auth.isLoading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
          ? const Center(child: AppText('프로필 정보를 불러올 수 없어요'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
              children: [
                Center(
                  child: ClipOval(
                    child: _previewBytes == null
                        ? AuthenticatedNetworkImage(
                            url: profile.profileImageUrl,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            fallback: _fallback(),
                          )
                        : Image.memory(
                            _previewBytes!,
                            key: const Key('my-profile-local-preview'),
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallback(),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _pickPhoto,
                    child: const AppText('사진 선택'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nickname,
                  decoration: const InputDecoration(labelText: '닉네임'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: '이메일'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  AppText(_error!, fontSize: 12, color: AppColors.danger),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => showPreparingToast(context),
                  child: const AppText('저장', color: AppColors.white),
                ),
              ],
            ),
    );
  }

  Widget _fallback() => Container(
    width: 96,
    height: 96,
    color: AppColors.surfaceSoft,
    alignment: Alignment.center,
    child: const Icon(
      Icons.person_outline_rounded,
      size: 42,
      color: AppColors.textSecondary,
    ),
  );
}
