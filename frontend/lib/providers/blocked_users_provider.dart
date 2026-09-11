import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/community_safety_service.dart';

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>((
  ref,
) {
  final actor = ref.watch(
    authProvider.select((s) => s.isAuthenticated ? s.profile?.id : null),
  );
  if (actor == null) return Future.value([]);
  return ref.watch(communitySafetyServiceProvider).getBlockedUsers();
});
