import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import '../core/app_colors.dart';
import '../core/app_interaction_style.dart';

/// InkWell with an independent, layout-neutral keyboard focus indicator.
class AppInkWell extends StatefulWidget {
  const AppInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onHover,
    this.onFocusChange,
    this.onHighlightChanged,
    this.borderRadius,
    this.customBorder,
    this.focusNode,
    this.statesController,
    this.splashColor,
    this.filled = false,
    this.danger = false,
    this.suppressPressOverlay = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onHighlightChanged;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final FocusNode? focusNode;
  final WidgetStatesController? statesController;
  final Color? splashColor;
  final bool filled;
  final bool danger;
  final bool suppressPressOverlay;

  @override
  State<AppInkWell> createState() => _AppInkWellState();
}

class _AppInkWellState extends State<AppInkWell> {
  FocusNode? _internalFocus;
  FocusNode get _focus => widget.focusNode ?? (_internalFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(AppInkWell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocus)?.removeListener(_focusChanged);
      _focus.addListener(_focusChanged);
    }
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _internalFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: widget.onTap,
    onHover: widget.onHover,
    onFocusChange: widget.onFocusChange,
    onHighlightChanged: widget.onHighlightChanged,
    focusNode: _focus,
    statesController: widget.statesController,
    borderRadius: widget.borderRadius,
    customBorder: widget.customBorder,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    highlightColor: Colors.transparent,
    overlayColor: widget.suppressPressOverlay
        ? const WidgetStatePropertyAll(Colors.transparent)
        : AppInteractionStyle.overlay(danger: widget.danger),
    splashFactory: widget.suppressPressOverlay ? NoSplash.splashFactory : null,
    splashColor: widget.splashColor,
    child: AppFocusRing(
      focused: widget.onTap != null && _focus.hasPrimaryFocus,
      filled: widget.filled,
      shape:
          widget.customBorder ??
          RoundedRectangleBorder(
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
          ),
      child: widget.child,
    ),
  );
}

/// Observes an existing standard control; never inserts a focus/traversal node.
class AppFocusIndicator extends StatefulWidget {
  const AppFocusIndicator({
    super.key,
    required this.child,
    this.shape = const RoundedRectangleBorder(),
    this.filled = false,
    this.enabled = true,
    this.focusNode,
    this.statesController,
  });

  final Widget child;
  final ShapeBorder shape;
  final bool filled;
  final bool enabled;
  final FocusNode? focusNode;
  final WidgetStatesController? statesController;

  @override
  State<AppFocusIndicator> createState() => _AppFocusIndicatorState();
}

class _AppFocusIndicatorState extends State<AppFocusIndicator> {
  bool _pendingRebuild = false;
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_changed);
    widget.statesController?.addListener(_changed);
  }

  @override
  void didUpdateWidget(AppFocusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statesController != oldWidget.statesController) {
      oldWidget.statesController?.removeListener(_changed);
      widget.statesController?.addListener(_changed);
    }
  }

  void _changed() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_pendingRebuild) return;
      _pendingRebuild = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingRebuild = false;
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  bool get _focused {
    if (!widget.enabled) return false;
    if (widget.focusNode != null) return widget.focusNode!.hasPrimaryFocus;
    if (widget.statesController != null) {
      return widget.statesController!.value.contains(WidgetState.focused) &&
          !widget.statesController!.value.contains(WidgetState.disabled);
    }
    var inside = false;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
      element,
    ) {
      if (element == context) inside = true;
      return !inside;
    });
    return inside;
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_changed);
    widget.statesController?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppFocusRing(
    focused: _focused,
    shape: widget.shape,
    filled: widget.filled,
    // RawChip/ListTile use Theme.focusColor internally even with a custom fill.
    // This observer supplies their ring, so suppress the duplicate tinted fill.
    child: Theme(
      data: Theme.of(context).copyWith(focusColor: Colors.transparent),
      child: widget.child,
    ),
  );
}

class AppFocusRing extends StatefulWidget {
  const AppFocusRing({
    super.key,
    required this.focused,
    required this.shape,
    required this.child,
    this.filled = false,
  });

  final bool focused;
  final ShapeBorder shape;
  final Widget child;
  final bool filled;

  /// ButtonStyle.backgroundBuilder paints over the full button, not its label.
  static Widget buttonBuilder(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) => Builder(
    builder: (context) {
      final material = context.findAncestorWidgetOfExactType<Material>();
      final color = material?.color;
      return AppFocusRing(
        focused:
            states.contains(WidgetState.focused) &&
            !states.contains(WidgetState.disabled),
        shape: material?.shape ?? const StadiumBorder(),
        filled: color != null && color.a > 0 && color != Colors.white,
        child: child ?? const SizedBox.shrink(),
      );
    },
  );

  @override
  State<AppFocusRing> createState() => _AppFocusRingState();
}

class _AppFocusRingState extends State<AppFocusRing> {
  @override
  void initState() {
    super.initState();
    _KeyboardMode.attach(_modeChanged);
  }

  void _modeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _KeyboardMode.detach(_modeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: widget.focused && _KeyboardMode.active
        ? _FocusPainter(widget.shape, widget.filled, Directionality.of(context))
        : null,
    child: widget.child,
  );
}

// Flutter's traditional highlight mode also includes mouse input. Track the
// actual input modality without adding Focus nodes or consuming key events.
abstract final class _KeyboardMode {
  static final _listeners = ValueNotifier(false);
  static int _users = 0;
  static bool get active => _listeners.value;

  static void attach(VoidCallback listener) {
    if (_users++ == 0) {
      HardwareKeyboard.instance.addHandler(_key);
      GestureBinding.instance.pointerRouter.addGlobalRoute(_pointer);
    }
    _listeners.addListener(listener);
  }

  static void detach(VoidCallback listener) {
    _listeners.removeListener(listener);
    if (--_users == 0) {
      HardwareKeyboard.instance.removeHandler(_key);
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointer);
      _listeners.value = false;
    }
  }

  static void _set(bool value) {
    if (active == value) return;
    _listeners.value = value;
  }

  static bool _key(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) _set(true);
    return false;
  }

  static void _pointer(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerHoverEvent) _set(false);
  }
}

class _FocusPainter extends CustomPainter {
  const _FocusPainter(this.shape, this.filled, this.direction);
  final ShapeBorder shape;
  final bool filled;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide <= 8) return;
    final path = shape.getOuterPath(
      (Offset.zero & size).deflate(3),
      textDirection: direction,
    );
    final paint = Paint()..style = PaintingStyle.stroke;
    if (filled) {
      canvas.drawPath(
        path,
        paint
          ..color = Colors.white
          ..strokeWidth = 4,
      );
    }
    canvas.drawPath(
      path,
      paint
        ..color = filled ? AppColors.text : AppColors.actionMint
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FocusPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.filled != filled ||
      oldDelegate.direction != direction;
}
