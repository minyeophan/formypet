import 'package:flutter/material.dart';
import '../../core/app_v2_tokens.dart';
import '../../services/inquiry_service.dart';

class InquiryTypeDropdown extends StatefulWidget {
  const InquiryTypeDropdown({super.key, required this.value, this.onChanged});
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  State<InquiryTypeDropdown> createState() => _InquiryTypeDropdownState();
}

class _InquiryTypeDropdownState extends State<InquiryTypeDropdown> {
  final _menu = MenuController();
  bool _open = false;

  @override
  void didUpdateWidget(covariant InquiryTypeDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onChanged == null && _menu.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _menu.isOpen) _menu.close();
      });
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      return MenuAnchor(
        controller: _menu,
        alignmentOffset: const Offset(0, 8),
        consumeOutsideTap: true,
        onOpen: () => setState(() => _open = true),
        onClose: () {
          if (mounted) setState(() => _open = false);
        },
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppV2Tokens.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(4),
          shadowColor: WidgetStatePropertyAll(
            AppV2Tokens.text.withValues(alpha: .15),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
          minimumSize: WidgetStatePropertyAll(Size(width, 0)),
          maximumSize: WidgetStatePropertyAll(Size(width, double.infinity)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppV2Tokens.border),
            ),
          ),
        ),
        menuChildren: [
          for (final entry in inquiryTypes.entries)
            Semantics(
              selected: widget.value == entry.key,
              child: MenuItemButton(
                key: Key('inquiry-type-option-${entry.key}'),
                onPressed: widget.onChanged == null
                    ? null
                    : () => widget.onChanged?.call(entry.key),
                style: ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(width - 16, 48)),
                  maximumSize: WidgetStatePropertyAll(
                    Size(width - 16, double.infinity),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  backgroundColor: WidgetStatePropertyAll(
                    widget.value == entry.key
                        ? AppV2Tokens.mintSurface
                        : AppV2Tokens.surface,
                  ),
                  overlayColor: const WidgetStatePropertyAll(
                    AppV2Tokens.mintSurface,
                  ),
                  foregroundColor: WidgetStatePropertyAll(
                    widget.value == entry.key
                        ? AppV2Tokens.primaryPressed
                        : AppV2Tokens.text,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(
                      fontSize: 14,
                      fontWeight: widget.value == entry.key
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
                trailingIcon: widget.value == entry.key
                    ? const Text(
                        '✓',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppV2Tokens.primaryPressed,
                        ),
                      )
                    : null,
                child: Text(entry.value),
              ),
            ),
        ],
        builder: (context, controller, child) => OutlinedButton(
          key: const Key('inquiry-type-trigger'),
          onPressed: widget.onChanged == null
              ? null
              : () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            foregroundColor: AppV2Tokens.text,
            backgroundColor: AppV2Tokens.surface,
            side: BorderSide(
              color: _open ? AppV2Tokens.primary : AppV2Tokens.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  inquiryTypes[widget.value]!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 18,
                color: AppV2Tokens.textSecondary,
              ),
            ],
          ),
        ),
      );
    },
  );
}
