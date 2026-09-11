import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/community/write_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final role in ['USER', 'ADMIN']) {
    testWidgets('$role has the correct news publishing choices', (
      tester,
    ) async {
      final profile = UserProfile.fromJson({
        'id': 1,
        'email': 'editor@example.test',
        'nickname': 'editor',
        'role': role,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (_) => AuthNotifier.test(
                AuthState(
                  isLoading: false,
                  isAuthenticated: true,
                  profile: profile,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: WriteScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('자유'));
      await tester.pumpAndSettle();
      final picker = tester.widget<CupertinoPicker>(
        find.byType(CupertinoPicker),
      );
      picker.scrollController!.jumpToItem(8);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('community-category-option-NEWS')),
        role == 'ADMIN' ? findsOneWidget : findsNothing,
      );
      if (role == 'ADMIN') {
        await tester.tap(find.text('완료'));
        await tester.pumpAndSettle();
        expect(find.text('소식'), findsOneWidget);
      }
    });
  }
}
