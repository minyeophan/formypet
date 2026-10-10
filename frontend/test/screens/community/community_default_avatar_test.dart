import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/community/community_comment_widgets.dart';
import 'package:frontend/widgets/app_icon.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('community author fallback uses the profile person icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CommunityCommentAvatar(url: null, size: 40)),
    );

    final icon = tester.widget<AppIcon>(find.byType(AppIcon));
    expect(icon.icon, Icons.person_outline_rounded);
    expect(icon.size, 17.5);
  });
}
