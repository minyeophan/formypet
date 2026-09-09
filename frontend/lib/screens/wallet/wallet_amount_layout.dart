import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Keep the reference row when it fits, then give the amount the full width.
/// Only reduce its type size if the user's scaled text still cannot fit there.
class WalletAmountLayout extends StatelessWidget {
  final TextEditingController controller;
  final double illustrationWidth;
  final Widget illustration;
  final double inputHorizontalPadding;
  final Widget Function(TextStyle style) amountBuilder;

  const WalletAmountLayout({
    super.key,
    required this.controller,
    required this.illustrationWidth,
    required this.illustration,
    required this.amountBuilder,
    this.inputHorizontalPadding = 0,
  });

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => LayoutBuilder(
          builder: (context, constraints) {
            final theme = Theme.of(context);
            final style =
                (theme.useMaterial3
                        ? theme.textTheme.bodyLarge!
                        : theme.textTheme.titleMedium!)
                    .copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    );
            final painter = TextPainter(
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              locale: Localizations.maybeLocaleOf(context),
              maxLines: 1,
            );
            double measure(double size) {
              painter.text = TextSpan(
                text: value.text.isEmpty ? '0원' : value.text,
                style: style.copyWith(fontSize: size),
              );
              painter.layout();
              return painter.width;
            }

            // Include InputDecorator padding and the editable's caret margin.
            final available = constraints.maxWidth - inputHorizontalPadding - 4;
            final width = measure(32);
            final stacked = width > available - illustrationWidth;
            var fontSize = 32.0;
            if (stacked && width > available) {
              var low = 0.0;
              var high = 32.0;
              for (var i = 0; i < 16; i++) {
                final candidate = (low + high) / 2;
                if (measure(candidate) <= available) {
                  low = candidate;
                } else {
                  high = candidate;
                }
              }
              fontSize = low;
            }
            painter.dispose();
            // The same Flex/Flexible ancestry preserves the editable and focus
            // when a keystroke changes the layout direction.
            return Flex(
              direction: stacked ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  flex: stacked ? 0 : 1,
                  fit: FlexFit.tight,
                  child: amountBuilder(style.copyWith(fontSize: fontSize)),
                ),
                Align(alignment: Alignment.centerRight, child: illustration),
              ],
            );
          },
        ),
      );
}
