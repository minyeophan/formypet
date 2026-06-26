import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/widgets/app_more_button.dart';

void main() {
  testWidgets('surface uses the shared vertical more action style', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppMoreButton.surface(
              key: const Key('surface-more'),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final finder = find.byKey(const Key('surface-more'));
    expect(tester.getSize(finder), const Size(38, 38));
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

    final container = tester.widget<Container>(
      find.descendant(of: finder, matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColors.surface);
    expect(decoration.border, Border.all(color: AppColors.border));
    expect(decoration.borderRadius, BorderRadius.circular(14));

    final icon = tester.widget<Icon>(
      find.descendant(of: finder, matching: find.byType(Icon)),
    );
    expect(icon.size, 20);
    expect(icon.color, AppColors.textSecondary);
  });

  testWidgets('plain keeps a 44px touch target with vertical more icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppMoreButton.plain(
              key: const Key('plain-more'),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final finder = find.byKey(const Key('plain-more'));
    expect(tester.getSize(finder), const Size(44, 44));
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

    final container = tester.widget<Container>(
      find.descendant(of: finder, matching: find.byType(Container)).first,
    );
    expect(container.decoration, isNull);
  });

  testWidgets('disabled button does not run tap callback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AppMoreButton.surface(key: Key('disabled-more'))),
        ),
      ),
    );

    final inkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('disabled-more')),
        matching: find.byType(InkWell),
      ),
    );
    expect(inkWell.onTap, isNull);

    await tester.tap(find.byKey(const Key('disabled-more')));
    await tester.pump();
  });
}
