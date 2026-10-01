import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/screens/community/community_detail_widgets.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:frontend/widgets/app_text.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shared header action is tappable at the edge of a 44px target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppHeaderIconButton(
              icon: Icons.settings_outlined,
              tooltip: '설정',
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(AppHeaderIconButton));
    await tester.tapAt(center + const Offset(21, 0));
    expect(taps, 1);
  });

  testWidgets('screen header variants use the same readable title scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: const AppHeader(title: '일정 추가'),
          body: Column(
            children: [
              AppInlineHeader(title: '일정 상세', onBack: () {}),
              AppFormHeader(title: '급식 기록', onBack: () {}),
            ],
          ),
        ),
      ),
    );
    for (final title in ['일정 추가', '일정 상세', '급식 기록']) {
      final label = tester.widget<AppText>(find.widgetWithText(AppText, title));
      expect(label.fontSize, 20, reason: title);
    }
  });

  testWidgets('community and shared text inherit the same Korean font', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Column(
            children: [
              const AppText('공통 본문', fontSize: 16),
              Text('커뮤니티 본문', style: communityV2Style(size: 16)),
            ],
          ),
        ),
      ),
    );
    String? family(String text) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      return (paragraph.text as TextSpan).style?.fontFamily;
    }

    expect(family('공통 본문'), isNotNull);
    expect(family('커뮤니티 본문'), family('공통 본문'));
  });

  testWidgets(
    'primary submit retains shared green through enabled and pressed states',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: FilledButton(onPressed: () {}, child: const Text('저장')),
            ),
          ),
        ),
      );
      Color? surfaceColor() => tester
          .widget<Material>(
            find.descendant(
              of: find.byType(FilledButton),
              matching: find.byType(Material),
            ),
          )
          .color;
      expect(surfaceColor(), AppColors.primary);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('저장')),
      );
      await tester.pumpAndSettle();
      expect(surfaceColor(), AppColors.primaryPressed);
      await gesture.up();
    },
  );
}
