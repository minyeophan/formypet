import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_logo.dart';

enum _AuthView { welcome, login, register }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

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
        await auth.register(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          nickname: _nicknameCtrl.text.trim(),
        );
      }
    } catch (error) {
      if (!mounted) return;
      _applyAuthError(error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithKakao() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _formError = null;
    });
    try {
      await ref.read(authProvider.notifier).loginWithKakao();
    } catch (error) {
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
      if (_passwordCtrl.text.length < 8) {
        errors['password'] = '비밀번호는 8자 이상 입력해 주세요.';
      }
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
          _show(_AuthView.welcome);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: _view == _AuthView.welcome ? _welcome() : _form(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcome() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BrandLogo(size: 210),
        const SizedBox(height: 20),
        const Text(
          '포마펫',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          '반려동물과의 매일을 더 편안하게',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFEE500),
              foregroundColor: const Color(0xFF191919),
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _isLoading ? null : _loginWithKakao,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF191919),
                    ),
                  )
                : const Text('카카오로 시작하기'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.text, width: 1.2),
              minimumSize: const Size.fromHeight(52),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
            onPressed: _isLoading ? null : () => _show(_AuthView.login),
            child: const Text('이메일로 로그인'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : () => _show(_AuthView.register),
          child: const Text('회원가입', style: TextStyle(color: AppColors.text)),
        ),
        if (_formError != null) _errorMessage(),
      ],
    );
  }

  Widget _form() {
    final registering = _view == _AuthView.register;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            key: const Key('auth-back-button'),
            onPressed: _isLoading ? null : () => _show(_AuthView.welcome),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        const SizedBox(height: 24),
        const Center(child: BrandLogo(size: 80)),
        const SizedBox(height: 16),
        Text(
          registering ? '회원가입' : '로그인',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 28),
        if (registering) ...[
          KeyedSubtree(
            key: _fieldKeys['nickname'],
            child: TextField(
              key: const Key('auth-nickname-field'),
              controller: _nicknameCtrl,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.nickname],
              onChanged: (_) => _clearFieldError('nickname'),
              decoration: InputDecoration(
                labelText: '닉네임',
                errorText: _fieldErrors['nickname'],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        KeyedSubtree(
          key: _fieldKeys['email'],
          child: TextField(
            key: const Key('auth-email-field'),
            controller: _emailCtrl,
            enabled: !_isLoading,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            onChanged: (_) => _clearFieldError('email'),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: '이메일',
              errorText: _fieldErrors['email'],
            ),
          ),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: _fieldKeys['password'],
          child: TextField(
            key: const Key('auth-password-field'),
            controller: _passwordCtrl,
            enabled: !_isLoading,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            autofillHints: [
              registering ? AutofillHints.newPassword : AutofillHints.password,
            ],
            onSubmitted: (_) => _submit(),
            onChanged: (_) => _clearFieldError('password'),
            obscureText: !_passwordVisible,
            decoration: InputDecoration(
              labelText: '비밀번호',
              errorText: _fieldErrors['password'],
              suffixIcon: IconButton(
                key: const Key('auth-password-visibility'),
                tooltip: _passwordVisible ? '비밀번호 숨기기' : '비밀번호 보기',
                onPressed: _isLoading
                    ? null
                    : () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                icon: Icon(
                  _passwordVisible ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_formError != null) ...[
          _errorMessage(),
          const SizedBox(height: 12),
        ],
        FilledButton(
          key: const Key('auth-submit-button'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary,
            disabledForegroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(registering ? '회원가입' : '로그인'),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => _show(registering ? _AuthView.login : _AuthView.register),
          child: Text(registering ? '로그인' : '회원가입'),
        ),
      ],
    );
  }

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
