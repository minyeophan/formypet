import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'app_ink_well.dart';
import 'app_text.dart';

class AppActionSheetItem {
  final Key? key;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  const AppActionSheetItem({
    this.key,
    required this.label,
    this.onTap,
    this.destructive = false,
  });
}

Future<void> showAppActionSheet(
  BuildContext context, {
  required String title,
  required List<AppActionSheetItem> actions,
  String closeLabel = '닫기',
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 600),
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(title, fontWeight: FontWeight.w700),
            const SizedBox(height: 18),
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActionButton(
                  key: action.key,
                  label: action.label,
                  destructive: action.destructive,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    action.onTap?.call();
                  },
                ),
              ),
            _ActionButton(
              key: const Key('app-action-sheet-close'),
              label: closeLabel,
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = destructive
        ? AppColors.dangerSoft
        : AppColors.surfaceSoft;
    final border = destructive ? AppColors.dangerBorder : AppColors.border;
    final foreground = destructive ? AppColors.danger : AppColors.textSecondary;
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: (destructive ? AppColors.danger : AppColors.primary)
            .withValues(alpha: .10),
      ),
      child: AppFocusIndicator(
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            hoverColor: Colors.transparent,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: AppText(
                label,
                color: foreground,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
