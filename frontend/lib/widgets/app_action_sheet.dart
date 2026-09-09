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
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(title, fontWeight: FontWeight.w700),
            const SizedBox(height: 18),
            for (final action in actions)
              Theme(
                data: Theme.of(sheetContext).copyWith(
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  splashColor:
                      (action.destructive
                              ? AppColors.danger
                              : AppColors.primary)
                          .withValues(alpha: .10),
                ),
                child: AppFocusIndicator(
                  child: ListTile(
                    key: action.key,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    title: Center(
                      child: AppText(
                        action.label,
                        color: action.destructive ? AppColors.danger : null,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      action.onTap?.call();
                    },
                  ),
                ),
              ),
            Theme(
              data: Theme.of(sheetContext).copyWith(
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: AppColors.primary.withValues(alpha: .10),
              ),
              child: AppFocusIndicator(
                child: ListTile(
                  key: const Key('app-action-sheet-close'),
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  title: Center(child: AppText(closeLabel)),
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
