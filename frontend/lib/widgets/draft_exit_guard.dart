import 'package:flutter/material.dart';

import 'app_confirm_dialog.dart';

/// Connects active forms to shell navigation, which does not pop their routes.
class DraftExitController {
  final _guards =
      <Object, ({Future<bool> Function() confirm, VoidCallback cancel})>{};

  Future<bool> confirmExit() async {
    for (final guard in _guards.values.toList().reversed) {
      if (!await guard.confirm()) return false;
    }
    return true;
  }

  void cancelExit() {
    for (final guard in _guards.values.toList()) {
      guard.cancel();
    }
  }
}

class DraftExitScope extends InheritedWidget {
  const DraftExitScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final DraftExitController controller;

  @override
  bool updateShouldNotify(DraftExitScope oldWidget) =>
      controller != oldWidget.controller;
}

class _DraftExitRegistration extends StatefulWidget {
  const _DraftExitRegistration({
    required this.confirmExit,
    required this.cancelExit,
    required this.child,
  });
  final Future<bool> Function() confirmExit;
  final VoidCallback cancelExit;
  final Widget child;

  @override
  State<_DraftExitRegistration> createState() => _DraftExitRegistrationState();
}

class _DraftExitRegistrationState extends State<_DraftExitRegistration> {
  DraftExitController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context
        .dependOnInheritedWidgetOfExactType<DraftExitScope>()
        ?.controller;
    if (controller == _controller) return;
    _controller?._guards.remove(this);
    _controller = controller;
    controller?._guards[this] = (
      confirm: () async {
        if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) {
          return true;
        }
        return widget.confirmExit();
      },
      cancel: () {
        if (mounted) widget.cancelExit();
      },
    );
  }

  @override
  void dispose() {
    _controller?._guards.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Protects both the header and system back path, without persisting drafts.
/// The owning form compares its values with its hydrated baseline.
mixin DraftExitGuardMixin<T extends StatefulWidget> on State<T> {
  bool get hasUnsavedChanges;
  bool get isDraftBusy;

  bool _draftExitAllowed = false;
  bool _draftConfirming = false;
  bool _draftExitRequested = false;
  bool get isDraftExiting => _draftExitRequested;

  void _cancelDraftExit() {
    if (!mounted) return;
    setState(() {
      _draftExitRequested = false;
      _draftExitAllowed = false;
    });
  }

  Widget protectDraft({required Widget child, required VoidCallback onExit}) {
    return _DraftExitRegistration(
      confirmExit: confirmDraftExit,
      cancelExit: _cancelDraftExit,
      child: PopScope<Object?>(
        canPop: _draftExitAllowed || (!isDraftBusy && !hasUnsavedChanges),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !isDraftBusy && !_draftConfirming) onExit();
        },
        child: ExcludeFocus(
          excluding: isDraftBusy || isDraftExiting,
          child: AbsorbPointer(
            absorbing: isDraftBusy || isDraftExiting,
            child: child,
          ),
        ),
      ),
    );
  }

  Future<bool> confirmDraftExit() async {
    if (!mounted || isDraftBusy || _draftConfirming || _draftExitRequested) {
      return false;
    }
    setState(() => _draftExitRequested = true);
    if (hasUnsavedChanges && !_draftExitAllowed) {
      _draftConfirming = true;
      FocusScope.of(context).unfocus();
      bool? discard;
      try {
        discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AppConfirmDialog(
            title: '입력을 그만할까요?',
            body: '저장하지 않은 변경사항은 사라져요.',
            actions: [
              AppConfirmDialogAction(
                label: '계속 입력',
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              AppConfirmDialogAction(
                label: '나가기',
                isDanger: true,
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
        );
      } finally {
        _draftConfirming = false;
      }
      if (!mounted || isDraftBusy || discard != true) {
        _cancelDraftExit();
        return false;
      }
    }
    await allowDraftExit();
    return mounted;
  }

  /// Use only after a successful save/delete, before navigating away.
  Future<void> allowDraftExit() async {
    if (!mounted) return;
    setState(() => _draftExitAllowed = true);
    // Navigator.pop consults the PopScope registered during the last build.
    await WidgetsBinding.instance.endOfFrame;
  }
}
