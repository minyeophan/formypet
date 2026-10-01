import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_v2_tokens.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../services/community_safety_service.dart';
import '../../widgets/app_header.dart';

const reportReasons = {
  'SPAM': '광고 / 스팸',
  'ABUSE': '욕설 / 괴롭힘',
  'INAPPROPRIATE': '부적절한 내용',
  'PRIVACY': '개인정보 노출',
  'OTHER': '기타',
};

class PostReportScreen extends ConsumerStatefulWidget {
  const PostReportScreen({super.key, required this.post});
  final Post post;
  @override
  ConsumerState<PostReportScreen> createState() => _PostReportScreenState();
}

class _PostReportScreenState extends ConsumerState<PostReportScreen> {
  final _detail = TextEditingController();
  String? _reason;
  String? _error;
  String? _draftKey;
  String? _requestId;
  bool _busy = false;
  bool _sessionChanged = false;
  ReportReceipt? _receipt;

  String? get _actor {
    final auth = ref.read(authProvider);
    return auth.isAuthenticated ? auth.profile?.id : null;
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      authProvider.select((s) => s.isAuthenticated ? s.profile?.id : null),
      (_, _) {
        _detail.clear();
        setState(() {
          _sessionChanged = true;
          _reason = null;
          _receipt = null;
          _busy = false;
          _error = '계정이 변경됐어요. 게시글에서 다시 열어 주세요.';
        });
      },
    );
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final actor = _actor;
    if (_busy ||
        _receipt != null ||
        _sessionChanged ||
        actor == null ||
        actor == widget.post.userId) {
      return;
    }
    if (_reason == null ||
        (_reason == 'OTHER' && _detail.text.trim().isEmpty)) {
      setState(
        () => _error = _reason == null
            ? '신고 사유를 선택해 주세요.'
            : '기타 사유의 상세 내용을 입력해 주세요.',
      );
      return;
    }
    final key = '$_reason\u0000${_detail.text.trim()}';
    if (_draftKey != key) {
      _draftKey = key;
      _requestId = newReportRequestId();
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await ref
          .read(communitySafetyServiceProvider)
          .reportPost(
            postId: widget.post.id,
            reason: _reason!,
            detail: _detail.text,
            requestId: _requestId!,
          );
      if (!mounted || _sessionChanged || _actor != actor) return;
      setState(() => _receipt = receipt);
    } catch (error) {
      if (!mounted || _sessionChanged || _actor != actor) return;
      setState(() => _error = reportErrorMessage(error));
    } finally {
      if (mounted && !_sessionChanged && _actor == actor) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final permitted =
        !_sessionChanged &&
        auth.isAuthenticated &&
        auth.profile != null &&
        auth.profile!.id != widget.post.userId;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppV2Tokens.background,
        appBar: AppHeader(
          title: '게시글 신고',
          showBackButton: true,
          centerTitle: true,
          onBack: () {
            if (!_busy) Navigator.of(context).pop();
          },
        ),
        body: SafeArea(
          child: _receipt != null
              ? _success()
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppV2Tokens.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '신고할 게시글',
                            style: TextStyle(color: AppV2Tokens.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (widget.post.title?.trim().isEmpty ?? true)
                                ? '제목 없음'
                                : widget.post.title!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(widget.post.authorNickname),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '신고 사유를 선택해 주세요',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in reportReasons.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          selected: _reason == entry.key,
                          button: true,
                          child: OutlinedButton(
                            key: Key('report-reason-${entry.key}'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppV2Tokens.text,
                              backgroundColor: _reason == entry.key
                                  ? AppV2Tokens.mintSurface
                                  : AppV2Tokens.surface,
                              minimumSize: const Size.fromHeight(48),
                              side: BorderSide(
                                color: _reason == entry.key
                                    ? AppV2Tokens.primary
                                    : AppV2Tokens.border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _busy || !permitted
                                ? null
                                : () => setState(() {
                                    _reason = entry.key;
                                    _error = null;
                                  }),
                            child: Row(
                              children: [
                                Icon(
                                  _reason == entry.key
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: _reason == entry.key
                                      ? AppV2Tokens.primary
                                      : AppV2Tokens.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(entry.value)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('report-detail'),
                      controller: _detail,
                      enabled: !_busy && permitted,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: _reason == 'OTHER'
                            ? '상세 내용 (필수)'
                            : '상세 내용 (선택)',
                        hintText: '신고할 내용을 자세히 적어 주세요.',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (!permitted)
                      Text(
                        _sessionChanged
                            ? _error!
                            : '본인 게시글은 신고할 수 없으며 로그인이 필요해요.',
                        style: const TextStyle(color: AppV2Tokens.error),
                      ),
                    if (_error != null && permitted)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppV2Tokens.error),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      '신고자 정보는 게시글 작성자에게 공개되지 않아요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppV2Tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('report-submit'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppV2Tokens.primary,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: _busy || !permitted || _reason == null
                          ? null
                          : _submit,
                      child: Text(
                        _busy
                            ? '접수 중…'
                            : _error == null
                            ? '신고 접수'
                            : '다시 접수하기',
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _success() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(
          Icons.check_circle_outline,
          size: 72,
          color: AppV2Tokens.primary,
        ),
        const SizedBox(height: 24),
        const Text(
          '신고가 접수됐어요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          '보내주신 내용을 확인하겠습니다.\n신고만으로 게시글이 바로 삭제되지는 않아요.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text('접수번호 ${_receipt!.id}', textAlign: TextAlign.center),
        const Spacer(),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('게시글로 돌아가기'),
        ),
      ],
    ),
  );
}
