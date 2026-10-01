import 'dart:convert';
import '../../widgets/draft_exit_guard.dart';
import '../../core/app_interaction_style.dart';
import '../../widgets/app_icon.dart';
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

class MyProfileScreen extends ConsumerStatefulWidget {
  final Future<XFile?> Function()? pickImage;

  const MyProfileScreen({super.key, this.pickImage});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen>
    with DraftExitGuardMixin<MyProfileScreen> {
  String? _baseline;
  String? _hydratedActor;
  bool _hydrating = false;
  int _pickerGeneration = 0;
  String get _snapshot =>
      jsonEncode([_nickname.text.trim(), _selectedPhoto?.path]);
  @override
  bool get hasUnsavedChanges => _baseline != null && _snapshot != _baseline;
  @override
  bool get isDraftBusy => _isSaving;
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      authProvider.select((auth) => (auth.isAuthenticated, auth.profile?.id)),
      (_, _) => _pickerGeneration++,
    );
    _nickname.addListener(() {
      if (mounted && !_hydrating) setState(() {});
    });
  }

  final _nickname = TextEditingController();
  final _email = TextEditingController();
  String? _hydratedEmail;
  XFile? _selectedPhoto;
  Uint8List? _previewBytes;
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_isSaving || isDraftExiting) return;
    final actor = _hydratedActor;
    final generation = ++_pickerGeneration;
    bool current() =>
        mounted &&
        !_isSaving &&
        !isDraftExiting &&
        generation == _pickerGeneration &&
        actor == _hydratedActor &&
        ref.read(authProvider).isAuthenticated &&
        ref.read(authProvider).profile?.id == actor;
    try {
      final file =
          await (widget.pickImage ??
              () => ImagePicker().pickImage(source: ImageSource.gallery))();
      if (!current() || file == null) return;
      final bytes = await file.readAsBytes();
      if (!current()) return;
      setState(() {
        _selectedPhoto = file;
        _previewBytes = bytes;
        _error = null;
      });
    } catch (_) {
      if (current()) setState(() => _error = '사진을 불러오지 못했어요.');
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;
    bool current() =>
        mounted && ref.read(authProvider).profile?.id == profile.id;
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      setState(() => _error = '닉네임을 입력해 주세요.');
      return;
    }
    if (nickname.length > 50) {
      setState(() => _error = '닉네임은 50자 이하로 입력해 주세요.');
      return;
    }

    final shouldUpdateNickname = nickname != profile.nickname;
    _pickerGeneration++;
    final selectedPhoto = _selectedPhoto;
    if (!shouldUpdateNickname && selectedPhoto == null) {
      await _goBack();
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    await dismissKeyboardBeforeTransition(context);
    if (!current()) return;

    if (shouldUpdateNickname) {
      try {
        await ref.read(authProvider.notifier).updateProfile(nickname: nickname);
      } catch (_) {
        if (current()) {
          setState(() {
            _isSaving = false;
            _error = '프로필을 저장하지 못했어요. 다시 시도해 주세요.';
          });
        }
        return;
      }
    }

    if (!current()) return;

    var photoUploadFailed = false;
    if (selectedPhoto != null) {
      Uint8List bytes;
      try {
        bytes = await selectedPhoto.readAsBytes();
      } catch (_) {
        if (current()) {
          setState(() {
            _isSaving = false;
            _selectedPhoto = null;
            _previewBytes = null;
            _error = '사진을 불러오지 못했어요.';
          });
        }
        return;
      }

      if (!current()) return;
      try {
        await ref
            .read(authProvider.notifier)
            .uploadProfileImage(bytes: bytes, filename: selectedPhoto.name);
      } catch (_) {
        photoUploadFailed = true;
        if (current()) {
          setState(() {
            _selectedPhoto = null;
            _previewBytes = null;
          });
        }
      }
    }

    if (!current()) return;
    setState(() => _isSaving = false);
    _showSaveMessage(
      photoUploadFailed && shouldUpdateNickname
          ? '닉네임은 저장했지만 사진을 등록하지 못했어요. 나중에 다시 추가할 수 있어요.'
          : photoUploadFailed
          ? '사진을 등록하지 못했어요. 나중에 다시 추가할 수 있어요.'
          : '프로필을 저장했어요.',
    );
    await allowDraftExit();
    if (!current()) return;
    await _goBack();
  }

  void _showSaveMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _goBack() async {
    if (!await confirmDraftExit() || !mounted) return;
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router?.canPop() ?? Navigator.of(context).canPop()) {
      if (router != null) {
        router.pop();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }
    if (router != null) {
      router.go('/my/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    final actor = auth.isAuthenticated ? profile?.id : null;
    if (_hydratedActor != actor || _hydratedEmail != profile?.email) {
      _hydrating = true;
      _hydratedActor = actor;
      _hydratedEmail = profile?.email;
      _nickname.text = profile?.nickname ?? '';
      _email.text = profile?.email ?? '';
      _selectedPhoto = null;
      _previewBytes = null;
      _isSaving = false;
      _error = null;
      _baseline = _snapshot;
      _hydrating = false;
    }

    return protectDraft(
      onExit: _goBack,
      child: Scaffold(
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
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
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
                      key: const Key('my-profile-photo-picker'),
                      onPressed: _isSaving ? null : _pickPhoto,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                      child: const AppText('사진 선택'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nickname,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(labelText: '닉네임'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    enabled: !_isSaving,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      fillColor: AppColors.surfaceSoft,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    AppText(_error!, fontSize: 12, color: AppColors.danger),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('my-profile-save'),
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                    ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                    child: const AppText('저장', color: AppColors.white),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _fallback() => Container(
    width: 96,
    height: 96,
    color: AppColors.surfaceSoft,
    alignment: Alignment.center,
    child: const AppIcon(
      Icons.person_outline_rounded,
      size: 42,
      color: AppColors.textSecondary,
    ),
  );
}
