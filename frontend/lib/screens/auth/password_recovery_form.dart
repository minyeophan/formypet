import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/password_policy.dart';
import '../../services/password_recovery_service.dart';
import '../../widgets/app_text.dart';

enum _Step { email, code, password, complete }

class PasswordRecoveryForm extends StatefulWidget {
  const PasswordRecoveryForm({
    super.key,
    required this.onClose,
    required this.onCompleted,
    this.service,
  });
  final VoidCallback onClose;
  final VoidCallback onCompleted;
  final PasswordRecoveryService? service;
  @override
  State<PasswordRecoveryForm> createState() => _PasswordRecoveryFormState();
}

class _PasswordRecoveryFormState extends State<PasswordRecoveryForm>
    with WidgetsBindingObserver {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final PasswordRecoveryService _service =
      widget.service ?? PasswordRecoveryService();
  _Step _step = _Step.email;
  RecoveryChallenge? _challenge;
  RecoveryVerified? _verified;
  String? _verifyId;
  String? _confirmId;
  String? _submittedCode;
  String? _submittedPassword;
  String? _error;
  bool _busy = false;
  bool _visible = false;
  int _generation = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_step == _Step.code || _step == _Step.password)) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _generation++;
    _submittedCode = null;
    _submittedPassword = null;
    _challenge = null;
    _verified = null;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in [_email, _code, _password, _confirmation]) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  void _restart() {
    _generation++;
    setState(() {
      _step = _Step.email;
      _busy = false;
      _challenge = null;
      _verified = null;
      _verifyId = null;
      _confirmId = null;
      _submittedCode = null;
      _submittedPassword = null;
      _error = null;
      _code.clear();
      _password.clear();
      _confirmation.clear();
    });
  }

  Future<void> _run(Future<void> Function(int) action) async {
    if (_busy) return;
    final generation = ++_generation;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(generation);
    } catch (error) {
      if (_current(generation)) {
        setState(() => _error = recoveryErrorMessage(error));
      }
    } finally {
      if (_current(generation)) setState(() => _busy = false);
    }
  }

  bool _current(int generation) => mounted && generation == _generation;
  void _invalid(String text) => setState(() => _error = text);

  Future<void> _request() async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      _invalid('올바른 이메일 주소를 입력해 주세요.');
      return;
    }
    await _run((generation) async {
      final result = await _service.request(_email.text);
      if (!_current(generation)) return;
      setState(() {
        _challenge = result;
        _step = _Step.code;
        _code.clear();
        _verifyId = null;
        _submittedCode = null;
        _verified = null;
      });
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    switch (_step) {
      case _Step.email:
        await _request();
      case _Step.code:
        if (!RegExp(r'^[0-9]{6}$').hasMatch(_code.text)) {
          _invalid('6자리 인증번호를 입력해 주세요.');
          return;
        }
        if (_submittedCode != _code.text) {
          _verifyId = recoveryRequestId();
          _submittedCode = _code.text;
        }
        await _run((generation) async {
          final result = await _service.verify(
            _challenge!.id,
            _code.text,
            _verifyId!,
          );
          if (!_current(generation)) return;
          setState(() {
            _verified = result;
            _step = _Step.password;
            _code.clear();
            _submittedCode = null;
          });
        });
      case _Step.password:
        final error = newPasswordError(_password.text);
        if (error != null) {
          _invalid(error);
          return;
        }
        if (_password.text != _confirmation.text) {
          _invalid('비밀번호가 일치하지 않아요.');
          return;
        }
        if (_submittedPassword != _password.text) {
          _confirmId = recoveryRequestId();
          _submittedPassword = _password.text;
        }
        await _run((generation) async {
          await _service.confirm(_verified!.token, _password.text, _confirmId!);
          if (!_current(generation)) return;
          setState(() {
            _step = _Step.complete;
            _verified = null;
            _challenge = null;
            _verifyId = null;
            _confirmId = null;
            _submittedCode = null;
            _submittedPassword = null;
            _password.clear();
            _confirmation.clear();
            _code.clear();
            _email.clear();
          });
        });
      case _Step.complete:
        break;
    }
  }

  int _remaining(DateTime date) =>
      date.difference(DateTime.now()).inSeconds.clamp(0, 86400);
  Widget _field({
    required String keyName,
    required String label,
    required TextEditingController controller,
    bool password = false,
    List<TextInputFormatter>? formatters,
    TextInputType? keyboard,
    ValueChanged<String>? changed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key(keyName),
        controller: controller,
        enabled: !_busy,
        obscureText: password && !_visible,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: keyboard,
        inputFormatters: formatters,
        onChanged: changed,
        autofillHints: password ? const [AutofillHints.newPassword] : null,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: password
              ? IconButton(
                  tooltip: _visible ? '비밀번호 숨기기' : '비밀번호 보기',
                  onPressed: () => setState(() => _visible = !_visible),
                  icon: Icon(
                    _visible ? Icons.visibility_off : Icons.visibility,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wait = _challenge == null
        ? 0
        : _remaining(_challenge!.resendAvailableAt);
    final expiry = _step == _Step.password
        ? _verified?.expiresAt
        : _challenge?.expiresAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: '로그인으로 돌아가기',
            onPressed: widget.onClose,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        const AppText('비밀번호 복구', fontSize: 26, fontWeight: FontWeight.bold),
        const SizedBox(height: 16),
        if (_step == _Step.complete) ...[
          const AppText('비밀번호를 변경했어요. 새 비밀번호로 다시 로그인해 주세요.'),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.onCompleted,
            child: const AppText('로그인으로 돌아가기'),
          ),
        ] else ...[
          const AppText('카카오로 가입했다면 카카오 로그인을 이용해 주세요.'),
          const SizedBox(height: 16),
          if (_step == _Step.email)
            _field(
              keyName: 'recovery-email',
              label: '이메일',
              controller: _email,
              keyboard: TextInputType.emailAddress,
            ),
          if (_step == _Step.code) ...[
            const AppText('이메일 가입 계정이라면 인증번호를 보내드립니다. 스팸함도 확인해 주세요.'),
            const AppText('메일이 늦게 도착할 수 있어요. 재전송했다면 최신 번호를 입력해 주세요.'),
            const SizedBox(height: 12),
            _field(
              keyName: 'recovery-code',
              label: '6자리 인증번호',
              controller: _code,
              keyboard: TextInputType.number,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),
            TextButton(
              key: const Key('recovery-resend'),
              onPressed: _busy || wait > 0 ? null : _request,
              child: AppText(wait > 0 ? '재전송 ($wait초)' : '인증번호 재전송'),
            ),
          ],
          if (_step == _Step.password) ...[
            const AppText('8자 이상, UTF-8 72바이트 이하로 입력해 주세요.'),
            _field(
              keyName: 'recovery-password',
              label: '새 비밀번호',
              controller: _password,
              password: true,
            ),
            _field(
              keyName: 'recovery-confirmation',
              label: '새 비밀번호 확인',
              controller: _confirmation,
              password: true,
            ),
          ],
          if (expiry != null)
            AppText(
              _remaining(expiry) > 0
                  ? '남은 시간: ${_remaining(expiry)}초'
                  : '유효시간이 지났어요. 복구를 다시 시작해 주세요.',
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(
                liveRegion: true,
                child: AppText(
                  _error!,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          FilledButton(
            key: const Key('recovery-submit'),
            onPressed: _busy ? null : _submit,
            child: AppText(
              _busy
                  ? '처리 중…'
                  : switch (_step) {
                      _Step.email => '인증번호 받기',
                      _Step.code => '인증번호 확인',
                      _ => '비밀번호 변경',
                    },
            ),
          ),
          if (_step != _Step.email)
            TextButton(
              onPressed: _restart,
              child: const AppText('이메일 변경 / 다시 시작'),
            ),
        ],
      ],
    );
  }
}
