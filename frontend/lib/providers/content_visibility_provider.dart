import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

final contentVisibilityRevisionProvider = StateProvider<int>((ref) => 0);

/// Separate from visibility so overlapping same-session mutations all commit.
final contentAccountSessionProvider =
    StateNotifierProvider<ContentAccountSession, Object>((ref) {
      final session = ContentAccountSession();
      ref.listen(
        authProvider.select((s) => s.isAuthenticated ? s.profile?.id : null),
        (_, _) => session.advance(),
      );
      return session;
    });

class ContentAccountSession extends StateNotifier<Object> {
  ContentAccountSession() : super(Object());
  void advance() => state = Object();
}

/// A new identity retires every request made under the previous visibility.
final contentVisibilityProvider = Provider<Object>((ref) {
  ref.watch(contentVisibilityRevisionProvider);
  ref.watch(contentAccountSessionProvider);
  return Object();
});
