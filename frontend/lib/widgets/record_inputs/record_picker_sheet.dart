import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../app_text.dart';
import 'record_input_style.dart';

Future<T?> showRecordPickerSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: RecordInputStyle.barrierColor,
    useSafeArea: false,
    builder: builder,
  );
}

class RecordPickerSheet<T> extends StatelessWidget {
  final Widget child;
  final T Function() value;

  const RecordPickerSheet({
    super.key,
    required this.child,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        MediaQuery.sizeOf(context).height *
        RecordInputStyle.sheetMaxHeightFactor;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: RecordInputStyle.surfaceColor,
            borderRadius: RecordInputStyle.sheetBorderRadius,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: RecordInputStyle.sheetHeaderHeight,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: TextButton(
                          key: const Key('record-picker-cancel'),
                          style: RecordInputStyle.headerButtonStyle,
                          onPressed: () => Navigator.of(context).pop(null),
                          child: const AppText(
                            '취소',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 96,
                        child: TextButton(
                          key: const Key('record-picker-done'),
                          style: RecordInputStyle.headerButtonStyle,
                          onPressed: () => Navigator.of(context).pop(value()),
                          child: const AppText(
                            '완료',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryPressed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: RecordInputStyle.borderColor),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
