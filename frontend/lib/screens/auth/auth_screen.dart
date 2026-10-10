import '../../widgets/app_icon.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/auth_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';

import '../../core/app_colors.dart';
import '../../core/app_interaction_style.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../core/password_policy.dart';
import 'password_recovery_form.dart';
import 'policy_consent_dialog.dart';
import '../../services/policy_service.dart';

enum _AuthView { welcome, login, register, recovery }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.initializationError,
    this.isInitializing = false,
    this.onRetryInitialization,
  });

  final String? initializationError;
  final bool isInitializing;
  final VoidCallback? onRetryInitialization;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthView _view = _AuthView.welcome;
  bool _isLoading = false;
  final Map<String, String> _fieldErrors = {};
  String? _formError;
  bool _passwordVisible = false;
  final _nicknameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _fieldKeys = {
    for (final name in ['nickname', 'email', 'password']) name: GlobalKey(),
  };
  final _errorKey = GlobalKey();

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _show(_AuthView view) {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _view = view;
      _passwordVisible = false;
      _fieldErrors.clear();
      _formError = null;
    });
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(errors);
      });
      _scrollToFirstError(errors);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authProvider.notifier);
      if (_view == _AuthView.login) {
        await auth.login(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      } else {
        final acceptance = await collectPolicyAcceptance(
          context,
          policyService: ref.read(policyServiceProvider),
        );
        if (acceptance == null) return;
        await auth.register(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          nickname: _nicknameCtrl.text.trim(),
          policyAcceptance: acceptance,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _applyAuthError(error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logKakaoFailure(Object error) {
    if (error is KakaoAuthException) {
      debugPrint('Kakao sign-in failed: providerCause=${error.error.name}');
      return;
    }
    if (error is DioException) {
      final apiError = error.error is ApiException
          ? error.error! as ApiException
          : null;
      debugPrint(
        'Kakao sign-in failed: type=${error.type.name}, '
        'path=${error.requestOptions.path}, '
        'status=${apiError?.statusCode ?? error.response?.statusCode}, '
        'code=${apiError?.errorCode ?? "unknown"}',
      );
      return;
    }
    debugPrint('Kakao sign-in failed: type=${error.runtimeType}');
  }

  Future<void> _loginWithKakao() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _formError = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .loginWithKakao(
            requestConsent: () => collectPolicyAcceptance(
              context,
              policyService: ref.read(policyServiceProvider),
            ),
          );
    } catch (error) {
      _logKakaoFailure(error);
      if (!mounted) return;
      _applyAuthError(error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyAuthError(Object error) {
    final apiError = error is ApiException
        ? error
        : error is DioException && error.error is ApiException
        ? error.error! as ApiException
        : null;
    final mappedFields = <String, String>{};
    if (apiError?.fieldErrors != null) {
      for (final entry in apiError!.fieldErrors!.entries) {
        if (!_fieldKeys.containsKey(entry.key) ||
            (entry.key == 'nickname' && _view != _AuthView.register)) {
          continue;
        }
        final raw = entry.value.toLowerCase();
        mappedFields[entry.key] =
            entry.key == 'email' &&
                (apiError.statusCode == 409 ||
                    raw.contains('duplicate') ||
                    raw.contains('이미 사용') ||
                    (apiError.statusCode == 400 &&
                        '${apiError.title} ${apiError.detail}'.contains(
                          '이미 사용',
                        )))
            ? '이미 사용 중인 이메일입니다.'
            : _fieldMessage(entry.key, raw);
      }
    }
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(mappedFields);
      _formError = mappedFields.isEmpty
          ? _friendlyMessage(error, apiError)
          : null;
    });
    if (mappedFields.isNotEmpty) {
      _scrollToFirstError(mappedFields);
    } else {
      _reveal(_errorKey);
    }
  }

  String _friendlyMessage(Object error, ApiException? apiError) {
    if (error is KakaoSignupInterrupted) return error.message;
    switch (apiError?.errorCode) {
      case 'POLICY_VERSION_CHANGED':
        return '정책이 변경됐어요. 최신 전문을 확인하고 다시 가입해 주세요.';
      case 'POLICY_ACCEPTANCE_REQUIRED':
        return '이용약관 동의와 만 14세 이상 확인이 필요해요. 최신 앱을 이용해 주세요.';
      case 'KAKAO_CLEANUP_PENDING':
        return '카카오 연결 정리가 진행 중이에요. 잠시 후 다시 시도해 주세요.';
      case 'KAKAO_SIGNUP_EXPIRED':
        return '가입 확인 시간이 만료됐어요. 카카오 로그인부터 다시 진행해 주세요.';
      case 'APP_UPDATE_REQUIRED':
        return '가입 동의를 지원하는 최신 앱으로 업데이트해 주세요.';
    }
    if (error is DioException &&
        (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout)) {
      return '네트워크 연결을 확인해 주세요.';
    }
    if (apiError?.statusCode == 401 || apiError?.statusCode == 403) {
      return '이메일 또는 비밀번호를 확인해 주세요.';
    }
    if (apiError?.statusCode == 409 ||
        '${apiError?.title} ${apiError?.detail}'.contains('이미 사용')) {
      return '이미 사용 중인 이메일입니다.';
    }
    return '잠시 후 다시 시도해 주세요.';
  }

  String _fieldMessage(String field, String message) {
    final label = switch (field) {
      'nickname' => '닉네임',
      'email' => '이메일',
      _ => '비밀번호',
    };
    if (message.contains('blank') ||
        message.contains('null') ||
        message.contains('필수') ||
        message.contains('비어')) {
      return '$label${field == 'password' ? '를' : '을'} 입력해 주세요.';
    }
    if (field == 'email') return '올바른 이메일 주소를 입력해 주세요.';
    if (message.contains('size') ||
        message.contains('length') ||
        message.contains('자 이상') ||
        message.contains('자 이하')) {
      if (field == 'nickname') return '닉네임은 50자 이하로 입력해 주세요.';
      return '비밀번호는 8자 이상 입력해 주세요.';
    }
    return '$label 입력 조건을 확인해 주세요.';
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      errors['email'] = '이메일을 입력해 주세요.';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      errors['email'] = '이메일을 확인해 주세요.';
    }
    if (_passwordCtrl.text.isEmpty) {
      errors['password'] = '비밀번호를 입력해 주세요.';
    }
    if (_view == _AuthView.register) {
      if (_nicknameCtrl.text.trim().isEmpty) {
        errors['nickname'] = '닉네임을 입력해 주세요.';
      } else if (_nicknameCtrl.text.trim().length > 50) {
        errors['nickname'] = '닉네임은 50자 이하로 입력해 주세요.';
      }
      final passwordError = newPasswordError(_passwordCtrl.text);
      if (passwordError != null) errors['password'] = passwordError;
    }
    return errors;
  }

  void _clearFieldError(String field) {
    if (_fieldErrors.containsKey(field) || _formError != null) {
      setState(() {
        _fieldErrors.remove(field);
        _formError = null;
      });
    }
  }

  void _scrollToFirstError(Map<String, String> errors) {
    for (final field in ['nickname', 'email', 'password']) {
      if (errors.containsKey(field)) {
        _reveal(_fieldKeys[field]!);
        return;
      }
    }
  }

  void _reveal(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          alignment: 0.15,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _view == _AuthView.welcome && !_isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _view != _AuthView.welcome && !_isLoading) {
          _show(
            _view == _AuthView.recovery ? _AuthView.login : _AuthView.welcome,
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final policyHeight = _view == _AuthView.welcome ? 68.0 : 54.0;
              final contentHeight = (constraints.maxHeight - policyHeight)
                  .clamp(0.0, double.infinity);
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: contentHeight),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 30, bottom: 10),
                          child: _view == _AuthView.recovery
                              ? PasswordRecoveryForm(
                                  onClose: () => _show(_AuthView.login),
                                  onCompleted: () {
                                    _passwordCtrl.clear();
                                    _show(_AuthView.login);
                                  },
                                )
                              : _view == _AuthView.welcome
                              ? _welcome()
                              : _form(),
                        ),
                      ),
                    ),
                  ),
                  _policyLinks(height: policyHeight),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _welcome() {
    final compact = MediaQuery.sizeOf(context).height < 700;
    final iconSize = compact ? 88.0 : 108.0;
    final isBusy = _isLoading || widget.isInitializing;
    final canContinue = !isBusy && widget.initializationError == null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            SizedBox(height: compact ? 18 : 140),
            ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 22 : 28),
              child: Image.asset(
                'assets/images/app_icon_p04.png',
                width: iconSize,
                height: iconSize,
                fit: BoxFit.cover,
                semanticLabel: '포마펫 앱 아이콘',
              ),
            ),
            SizedBox(height: compact ? 14 : 16),
            const Text(
              '포마펫',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.actionMint,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.5,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '우리 아이의 모든 순간을 기록하다',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (widget.initializationError != null) ...[
              const SizedBox(height: 18),
              Text(
                widget.initializationError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: widget.onRetryInitialization,
                child: const Text('다시 시도'),
              ),
            ],
          ],
        ),
        Padding(
          padding: EdgeInsets.only(top: compact ? 8 : 24),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: AppColors.text,
                    minimumSize: const Size.fromHeight(56),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                  onPressed: canContinue ? _loginWithKakao : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.text,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/images/auth_kakao.svg',
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              '카카오로 시작하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: Color(0xFFE1E5E2)),
                    minimumSize: const Size.fromHeight(56),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                  onPressed: canContinue ? () => _show(_AuthView.login) : null,
                  child: const Text(
                    '이메일로 로그인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                  onPressed: canContinue
                      ? () => _show(_AuthView.register)
                      : null,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '처음 오셨나요?',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '회원가입',
                        style: TextStyle(
                          color: AppColors.actionMint,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_formError != null) _errorMessage(),
      ],
    );
  }

  Widget _policyLinks({required double height}) => SizedBox(
    height: height,
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _policyButton('이용약관'),
          const SizedBox(width: 18),
          _policyButton('개인정보 처리방침'),
        ],
      ),
    ),
  );

  Widget _policyButton(String label) => TextButton(
    onPressed: () => context.push('/my/policies'),
    style: TextButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12, height: 1.5),
    ).copyWith(overlayColor: AppInteractionStyle.overlay()),
    child: Text(label),
  );

  Widget _form() {
    final registering = _view == _AuthView.register;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              key: const Key('auth-back-button'),
              padding: EdgeInsets.zero,
              onPressed: _isLoading ? null : () => _show(_AuthView.welcome),
              icon: const AppIcon(Icons.arrow_back, size: 24),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (registering) ...[
              SizedBox(height: 112, child: Center(child: _AuthBrandLockup())),
              const SizedBox(height: 22),
            ] else
              const SizedBox(height: 22),
            Text(
              registering ? '포마펫과 함께 시작해요' : '다시 만나 반가워요',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 25,
                fontWeight: FontWeight.w700,
                height: 38 / 25,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              registering ? '우리 아이와의 소중한 일상을 담아보세요.' : '이메일로 로그인하고 일상을 이어가세요.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 20 / 13,
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
        if (registering) ...[
          KeyedSubtree(
            key: _fieldKeys['nickname'],
            child: _authField(
              label: '닉네임',
              hint: '사용할 닉네임을 입력해 주세요',
              fieldKey: const Key('auth-nickname-field'),
              controller: _nicknameCtrl,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.nickname],
              errorText: _fieldErrors['nickname'],
              onChanged: (_) => _clearFieldError('nickname'),
              enabled: !_isLoading,
            ),
          ),
          const SizedBox(height: 16),
        ],
        KeyedSubtree(
          key: _fieldKeys['email'],
          child: _authField(
            label: '이메일',
            hint: '이메일 주소를 입력해 주세요',
            fieldKey: const Key('auth-email-field'),
            controller: _emailCtrl,
            enabled: !_isLoading,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            errorText: _fieldErrors['email'],
            onChanged: (_) => _clearFieldError('email'),
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _fieldKeys['password'],
          child: _authField(
            label: '비밀번호',
            hint: registering ? '8자 이상 입력해 주세요' : '비밀번호를 입력해 주세요',
            fieldKey: const Key('auth-password-field'),
            controller: _passwordCtrl,
            enabled: !_isLoading,
            textInputAction: TextInputAction.done,
            autofillHints: [
              registering ? AutofillHints.newPassword : AutofillHints.password,
            ],
            onSubmitted: (_) => _submit(),
            onChanged: (_) => _clearFieldError('password'),
            obscureText: !_passwordVisible,
            errorText: _fieldErrors['password'],
            suffixIcon: IconButton(
              key: const Key('auth-password-visibility'),
              tooltip: _passwordVisible ? '비밀번호 숨기기' : '비밀번호 보기',
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _passwordVisible = !_passwordVisible),
              icon: AppIcon(
                _passwordVisible ? Icons.visibility_off : Icons.visibility,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_formError != null) ...[_errorMessage(), const SizedBox(height: 8)],
        FilledButton(
          key: const Key('auth-submit-button'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.primary,
            disabledForegroundColor: AppColors.onPrimary,
            minimumSize: const Size.fromHeight(56),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ).copyWith(overlayColor: AppInteractionStyle.overlay()),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : Text(registering ? '회원가입' : '로그인'),
        ),
        if (!registering)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              key: const Key('auth-password-recovery'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ).copyWith(overlayColor: AppInteractionStyle.overlay()),
              onPressed: _isLoading
                  ? null
                  : () {
                      _passwordCtrl.clear();
                      _show(_AuthView.recovery);
                    },
              child: const Text('비밀번호를 잊으셨나요?', style: TextStyle(fontSize: 13)),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ).copyWith(overlayColor: AppInteractionStyle.overlay()),
            onPressed: _isLoading
                ? null
                : () =>
                      _show(registering ? _AuthView.login : _AuthView.register),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  registering ? '이미 계정이 있나요?' : '처음 오셨나요?',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  registering ? '로그인' : '회원가입',
                  style: const TextStyle(
                    color: AppColors.actionMint,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _authField({
    required String label,
    required String hint,
    required Key fieldKey,
    required TextEditingController controller,
    required bool enabled,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    bool autocorrect = true,
    TextInputType? keyboardType,
    String? errorText,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    bool obscureText = false,
    Widget? suffixIcon,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 20 / 13,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        key: fieldKey,
        controller: controller,
        enabled: enabled,
        autocorrect: autocorrect,
        enableSuggestions: false,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        obscureText: obscureText,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 14,
          height: 21 / 14,
          letterSpacing: -0.2,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 21 / 14,
            letterSpacing: -0.2,
          ),
          errorText: errorText,
          errorStyle: const TextStyle(
            color: AppColors.danger,
            fontSize: 12,
            height: 16 / 12,
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: _authInputBorder(),
          border: _authInputBorder(),
          focusedBorder: _authInputBorder(color: AppColors.actionMint),
          errorBorder: _authInputBorder(color: AppColors.dangerBorder),
          focusedErrorBorder: _authInputBorder(
            color: AppColors.danger,
            width: 1.5,
          ),
          suffixIcon: suffixIcon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: suffixIcon,
                ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
        ),
      ),
    ],
  );

  OutlineInputBorder _authInputBorder({
    Color color = const Color(0xFFE1E5E2),
    double width = 1,
  }) => OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(14)),
    borderSide: BorderSide(color: color, width: width),
  );

  Widget _errorMessage() => Semantics(
    key: _errorKey,
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _formError!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.danger),
      ),
    ),
  );
}

class _AuthBrandLockup extends StatelessWidget {
  const _AuthBrandLockup();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Image.asset(
        'assets/images/app_icon_p04.png',
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        semanticLabel: '포마펫 앱 아이콘',
      ),
      const SizedBox(height: 4),
      const Text(
        '포마펫',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.actionMint,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.4,
          letterSpacing: -.4,
        ),
      ),
    ],
  );
}
