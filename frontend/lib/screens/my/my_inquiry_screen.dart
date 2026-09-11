import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_v2_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../services/inquiry_service.dart';
import '../../widgets/app_header.dart';
import 'my_support_widgets.dart';
import 'inquiry_type_dropdown.dart';

class MyInquiryScreen extends ConsumerStatefulWidget {
  const MyInquiryScreen({super.key});
  @override
  ConsumerState<MyInquiryScreen> createState() => _MyInquiryScreenState();
}

class _MyInquiryScreenState extends ConsumerState<MyInquiryScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _type = inquiryTypes.keys.first;
  bool _busy = false;
  bool _validated = false;
  bool _sessionChanged = false;
  String? _error;
  String? _fingerprint;
  String? _requestId;
  InquiryReceipt? _receipt;
  String? _submittedEmail;

  String? get _actor {
    final auth = ref.read(authProvider);
    return auth.isAuthenticated ? auth.profile?.id : null;
  }

  @override
  void initState() {
    super.initState();
    if (_actor != null) _email.text = ref.read(authProvider).profile!.email;
    ref.listenManual(
      authProvider.select((s) => s.isAuthenticated ? s.profile?.id : null),
      (_, _) {
        _email.clear();
        _title.clear();
        _body.clear();
        setState(() {
          _sessionChanged = true;
          _validated = false;
          _type = inquiryTypes.keys.first;
          _busy = false;
          _receipt = null;
          _submittedEmail = null;
          _fingerprint = null;
          _requestId = null;
          _error = null;
        });
      },
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final actor = _actor;
    if (_busy || _sessionChanged || actor == null || _receipt != null) return;
    setState(() => _validated = true);
    if (!_form.currentState!.validate()) return;
    final draft = InquiryDraft(
      type: _type,
      replyEmail: _email.text,
      title: _title.text,
      body: _body.text,
    );
    if (_fingerprint != draft.fingerprint) {
      _fingerprint = draft.fingerprint;
      _requestId = newInquiryRequestId();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await ref
          .read(inquiryServiceProvider)
          .submit(draft, requestId: _requestId!);
      if (!mounted || _sessionChanged || _actor != actor) return;
      setState(() {
        _receipt = receipt;
        _submittedEmail = draft.replyEmail;
      });
    } catch (error) {
      if (!mounted || _sessionChanged || _actor != actor) return;
      setState(() => _error = inquiryErrorMessage(error));
    } finally {
      if (mounted && !_sessionChanged && _actor == actor) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final allowed =
        !_sessionChanged && auth.isAuthenticated && auth.profile != null;
    final enabled = allowed && !_busy;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppV2Tokens.background,
        appBar: AppHeader(
          title: '1대1 문의하기',
          showBackButton: true,
          centerTitle: true,
          onBack: () {
            if (!_busy) goBackOrFallback(context, '/my');
          },
        ),
        body: SafeArea(
          child: _receipt != null
              ? _success()
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _form,
                          autovalidateMode: _validated && allowed
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                '문의하신 내용은 이메일로 답변드려요.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppV2Tokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _field(
                                '문의 유형 *',
                                InquiryTypeDropdown(
                                  key: ValueKey(
                                    'inquiry-type-$_sessionChanged',
                                  ),
                                  value: _type,
                                  onChanged: enabled
                                      ? (value) => setState(() => _type = value)
                                      : null,
                                ),
                              ),
                              _field(
                                '답변받을 이메일 *',
                                TextFormField(
                                  key: const Key('inquiry-email'),
                                  controller: _email,
                                  enabled: enabled,
                                  style: const TextStyle(fontSize: 14),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  decoration: _decoration(
                                    hint: '답변받을 이메일을 입력해 주세요',
                                  ),
                                  maxLength: 254,
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty) {
                                      return '답변받을 이메일을 입력해 주세요.';
                                    }
                                    if (!RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(email)) {
                                      return '올바른 이메일 주소를 입력해 주세요.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              _field(
                                '제목 *',
                                TextFormField(
                                  key: const Key('inquiry-title'),
                                  controller: _title,
                                  enabled: enabled,
                                  style: const TextStyle(fontSize: 14),
                                  textInputAction: TextInputAction.next,
                                  decoration: _decoration(
                                    hint: '문의 제목을 입력해 주세요',
                                  ),
                                  maxLength: 100,
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? '제목을 입력해 주세요.'
                                      : null,
                                ),
                              ),
                              _field(
                                '문의 내용 *',
                                TextFormField(
                                  key: const Key('my-inquiry-body-field'),
                                  controller: _body,
                                  enabled: enabled,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                  minLines: 6,
                                  maxLines: 10,
                                  decoration: _decoration(
                                    hint:
                                        '어떤 점이 궁금하거나 불편하셨나요?\n상황을 자세히 적어 주세요.',
                                  ),
                                  maxLength: 2000,
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? '문의 내용을 입력해 주세요.'
                                      : null,
                                ),
                              ),
                              if (!allowed)
                                _notice(
                                  _sessionChanged
                                      ? '계정이 변경됐어요. 마이페이지에서 다시 열어 주세요.'
                                      : '로그인 후 문의를 작성해 주세요.',
                                ),
                              if (_busy)
                                _notice(
                                  '문의 내용을 보내고 있어요. 잠시만 기다려 주세요.',
                                  busy: true,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _footer(
                      FilledButton(
                        key: const Key('inquiry-submit'),
                        onPressed: enabled ? _submit : null,
                        style: _buttonStyle(),
                        child: Text(
                          _busy
                              ? '접수 중…'
                              : _error == null
                              ? '문의 접수'
                              : '다시 접수하기',
                        ),
                      ),
                      notice: '비밀번호 등 민감한 정보는 적지 말아 주세요.',
                      status: _error != null && allowed
                          ? _notice(_error!, title: '접수하지 못했어요')
                          : null,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _field(String label, Widget input) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        input,
      ],
    ),
  );

  InputDecoration _decoration({String? hint}) => InputDecoration(
    hintText: hint,
    counterText: '',
    errorMaxLines: 3,
    hintStyle: const TextStyle(color: AppV2Tokens.textSecondary, fontSize: 14),
    filled: true,
    fillColor: AppV2Tokens.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppV2Tokens.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppV2Tokens.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppV2Tokens.primary),
    ),
  );

  Widget _notice(String message, {String? title, bool busy = false}) =>
      Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: busy ? AppV2Tokens.mintSurface : AppV2Tokens.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppV2Tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );

  ButtonStyle _buttonStyle() => FilledButton.styleFrom(
    backgroundColor: AppV2Tokens.primary,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );

  Widget _footer(Widget button, {String? notice, Widget? status}) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status != null) ...[status, const SizedBox(height: 12)],
        if (notice != null) ...[
          Text(
            notice,
            style: const TextStyle(
              fontSize: 12,
              color: AppV2Tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
        ],
        button,
      ],
    ),
  );

  Widget _success() => Column(
    children: [
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppV2Tokens.mintSurface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 38,
                        color: AppV2Tokens.primaryPressed,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '문의가 접수됐어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  '보내주신 내용을 확인한 뒤\n아래 이메일로 답변드릴게요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppV2Tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppV2Tokens.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '답변받을 이메일',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppV2Tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _submittedEmail!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      _footer(
        FilledButton(
          key: const Key('inquiry-done'),
          onPressed: () => context.go('/my'),
          style: _buttonStyle(),
          child: const Text('마이페이지로 돌아가기'),
        ),
      ),
    ],
  );
}
