import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_v2_tokens.dart';
import '../providers/auth_provider.dart';
import '../services/community_safety_service.dart';

Future<bool?> showUserBlockSheet(
  BuildContext context, {
  required BlockedUser user,
  bool unblock = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppV2Tokens.surface,
    builder: (_) => _UserBlockSheet(user: user, unblock: unblock),
  );
}

class _UserBlockSheet extends ConsumerStatefulWidget {
  const _UserBlockSheet({required this.user, required this.unblock});
  final BlockedUser user;
  final bool unblock;
  @override
  ConsumerState<_UserBlockSheet> createState() => _UserBlockSheetState();
}

class _UserBlockSheetState extends ConsumerState<_UserBlockSheet> {
  bool _busy = false;
  bool _sessionChanged = false;
  String? _error;
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
        setState(() {
          _sessionChanged = true;
          _busy = false;
          _error = '계정이 변경됐어요. 목록이나 게시글에서 다시 열어 주세요.';
        });
      },
    );
  }

  Future<void> _submit() async {
    final actor = _actor;
    if (_busy ||
        _sessionChanged ||
        actor == null ||
        actor == widget.user.userId) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(communitySafetyServiceProvider);
      if (widget.unblock) {
        await service.unblock(widget.user.userId);
      } else {
        await service.block(widget.user.userId);
      }
      if (!mounted || _sessionChanged || _actor != actor) return;
      // Enable popping before removing the route.
      setState(() => _busy = false);
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted || _sessionChanged || _actor != actor) return;
      setState(() {
        _busy = false;
        _error = widget.unblock
            ? '차단을 해제하지 못했어요. 다시 시도해 주세요.'
            : '차단하지 못했어요. 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = _actor;
    final allowed =
        !_sessionChanged && actor != null && actor != widget.user.userId;
    final action = widget.unblock ? '차단 해제' : '차단';
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.unblock ? '차단을 해제할까요?' : '작성자를 차단할까요?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.user.nickname,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.unblock
                    ? '해제하면 이 사용자의 게시글을 다시 볼 수 있어요.'
                    : '이 사용자를 차단 목록에 추가해요. 마이페이지에서 차단을 해제할 수 있어요.',
              ),
              if (!allowed && !_sessionChanged)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('로그인 상태와 차단 대상을 확인해 주세요.'),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppV2Tokens.error),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('user-block-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppV2Tokens.primary,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _busy || !allowed ? null : _submit,
                child: Text(_busy ? '처리 중…' : action),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
