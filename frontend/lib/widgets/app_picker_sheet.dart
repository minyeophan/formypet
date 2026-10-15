import 'app_icon.dart';
import 'package:flutter/material.dart';
import 'app_ink_well.dart';

import '../core/app_colors.dart';
import '../core/app_interaction_style.dart';
import 'app_text.dart';

class AppSelectOption<T> {
  final T value;
  final String label;

  const AppSelectOption({required this.value, required this.label});
}

class AppSelectField<T> extends StatelessWidget {
  final String label;
  final String valueLabel;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final IconData icon;
  final bool searchable;

  const AppSelectField({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.options,
    required this.onChanged,
    this.icon = Icons.expand_more_rounded,
    this.searchable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: AppInkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final selected = await showAppPickerSheet<T>(
            context,
            title: label,
            options: options,
            searchable: searchable,
          );
          if (selected != null) {
            onChanged(selected);
          }
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppText(
                      label,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      valueLabel,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppIcon(icon, size: 22, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showAppPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<AppSelectOption<T>> options,
  T? selectedValue,
  bool searchable = false,
  bool showDragHandle = false,
  bool showCloseAction = true,
  bool showSeparators = true,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    useSafeArea: false,
    isScrollControlled: true,
    showDragHandle: false,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
    builder: (context) => AppPickerSheet<T>(
      showDragHandle: showDragHandle,
      title: title,
      options: options,
      selectedValue: selectedValue,
      searchable: searchable,
      showCloseAction: showCloseAction,
      showSeparators: showSeparators,
    ),
  );
}

class AppPickerSheet<T> extends StatefulWidget {
  final bool showDragHandle;
  final String title;
  final List<AppSelectOption<T>> options;
  final T? selectedValue;
  final bool searchable;
  final bool showCloseAction;
  final bool showSeparators;

  const AppPickerSheet({
    super.key,
    this.showDragHandle = false,
    required this.title,
    required this.options,
    this.selectedValue,
    this.searchable = false,
    this.showCloseAction = true,
    this.showSeparators = true,
  });

  @override
  State<AppPickerSheet<T>> createState() => _AppPickerSheetState<T>();
}

class _AppPickerSheetState<T> extends State<AppPickerSheet<T>> {
  final _queryCtrl = TextEditingController();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryCtrl.text.trim().toLowerCase();
    final options = query.isEmpty
        ? widget.options
        : widget.options
              .where((option) => option.label.toLowerCase().contains(query))
              .toList();
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: AppColors.primary.withValues(alpha: .10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showDragHandle)
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 4),
                    child: Container(
                      key: const Key('app-picker-drag-handle'),
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: 72),
                      Expanded(
                        child: Center(
                          child: AppText(
                            widget.title,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: widget.showCloseAction
                            ? TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(null),
                                child: const AppText(
                                  '닫기',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                if (widget.showSeparators)
                  const Divider(height: 1, color: AppColors.border),
                if (widget.searchable) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _queryCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '검색',
                        prefixIcon: const AppIcon(
                          Icons.search_rounded,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppInteractionStyle.inputFill,
                        hoverColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(
                      vertical: widget.showSeparators ? 8 : 4,
                    ),
                    itemCount: options.length,
                    separatorBuilder: (_, _) => widget.showSeparators
                        ? const Divider(height: 1, color: AppColors.border)
                        : const SizedBox(height: 0),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected =
                          widget.selectedValue != null &&
                          option.value == widget.selectedValue;
                      if (widget.selectedValue != null) {
                        return AppFocusIndicator(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                            child: Material(
                              color: isSelected
                                  ? AppColors.actionMint
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () =>
                                    Navigator.of(context).pop(option.value),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 36,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: AppText(
                                        option.label,
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return AppFocusIndicator(
                        child: ListTile(
                          hoverColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          dense: true,
                          minTileHeight: 48,
                          title: AppText(
                            option.label,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                          onTap: () => Navigator.of(context).pop(option.value),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<Set<T>?> showAppMultiPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<AppSelectOption<T>> options,
  required Set<T> selectedValues,
  bool searchable = true,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<Set<T>>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    useSafeArea: false,
    isScrollControlled: true,
    builder: (context) => AppMultiPickerSheet<T>(
      title: title,
      options: options,
      selectedValues: selectedValues,
      searchable: searchable,
    ),
  );
}

class AppMultiPickerSheet<T> extends StatefulWidget {
  final String title;
  final List<AppSelectOption<T>> options;
  final Set<T> selectedValues;
  final bool searchable;

  const AppMultiPickerSheet({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValues,
    this.searchable = true,
  });

  @override
  State<AppMultiPickerSheet<T>> createState() => _AppMultiPickerSheetState<T>();
}

class _AppMultiPickerSheetState<T> extends State<AppMultiPickerSheet<T>> {
  final _queryCtrl = TextEditingController();
  late final Set<T> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<T>.from(widget.selectedValues);
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryCtrl.text.trim().toLowerCase();
    final options = query.isEmpty
        ? widget.options
        : widget.options
              .where((option) => option.label.toLowerCase().contains(query))
              .toList();

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: AppColors.primary.withValues(alpha: .10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          child: const AppText(
                            '취소',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: AppText(
                            widget.title,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(_selected),
                          child: const AppText(
                            '완료',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                if (widget.searchable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _queryCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '검색',
                        prefixIcon: const AppIcon(
                          Icons.search_rounded,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppInteractionStyle.inputFill,
                        hoverColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final selected = _selected.contains(option.value);
                      return AppFocusIndicator(
                        child: CheckboxListTile(
                          hoverColor: Colors.transparent,
                          overlayColor: AppInteractionStyle.overlay(),
                          dense: true,
                          value: selected,
                          title: AppText(
                            option.label,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                          activeColor: AppColors.text,
                          controlAffinity: ListTileControlAffinity.trailing,
                          onChanged: (_) => setState(() {
                            if (selected) {
                              _selected.remove(option.value);
                            } else {
                              _selected.add(option.value);
                            }
                          }),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
