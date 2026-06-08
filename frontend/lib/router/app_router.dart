import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/records/expense_add_screen.dart';
import '../screens/records/expense_report_screen.dart';
import '../screens/records/expense_wallet_screen.dart';
import '../screens/records/meal_record_screen.dart';
import '../screens/records/record_category_form_screen.dart';
import '../screens/records/record_detail_screen.dart';
import '../screens/records/record_edit_screen.dart';
import '../screens/records/records_screen.dart';
import '../screens/routine/routine_create_screen.dart';
import '../screens/routine/routine_schedule_create_screen.dart';
import '../screens/routine/routine_screen.dart';
import '../screens/community/community_screen.dart';
import '../screens/community/write_screen.dart';
import '../screens/pet/pet_detail_screen.dart';
import '../screens/pet/pet_edit_screen.dart';
import '../screens/my/my_screen.dart';
import '../screens/my/my_pets_screen.dart';
import '../screens/my/my_profile_screen.dart';
import '../screens/my/my_settings_screen.dart';
import '../widgets/main_scaffold.dart';

// RouterNotifier listens to auth/pet providers and triggers router refresh.
// This avoids recreating GoRouter on every state change.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (prev, next) => notifyListeners());
    _ref.listen<PetState>(petProvider, (prev, next) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final petState = _ref.read(petProvider);

    if (authState.isLoading || petState.isLoading) return null;

    final isAuthenticated = authState.isAuthenticated;
    final hasOnboarded = petState.hasOnboarded;
    final path = state.matchedLocation;

    if (!isAuthenticated) {
      return path == '/auth' ? null : '/auth';
    }
    if (!hasOnboarded) {
      return path == '/onboarding' ? null : '/onboarding';
    }
    if (path == '/auth' || path == '/onboarding' || path == '/') {
      return '/home';
    }
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/auth', builder: (c, s) => const AuthScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (c, s) => const OnboardingScreen(mode: PetEntryMode.firstPet),
      ),
      GoRoute(
        path: '/pets/new',
        builder: (c, s) =>
            const OnboardingScreen(mode: PetEntryMode.additionalPet),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          GoRoute(
            path: '/community',
            builder: (c, s) => const CommunityScreen(),
          ),
          GoRoute(
            path: '/community/category/:category',
            builder: (c, s) => CommunityCategoryScreen(
              initialCategory: s.pathParameters['category']!,
            ),
          ),
          GoRoute(path: '/my', builder: (c, s) => const MyScreen()),
          GoRoute(
            path: '/my/settings',
            builder: (c, s) => const MySettingsScreen(),
          ),
          GoRoute(path: '/my/pets', builder: (c, s) => const MyPetsScreen()),
          GoRoute(
            path: '/my/profile',
            builder: (c, s) => const MyProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/records',
        redirect: (c, s) =>
            s.uri.queryParameters['tab'] == 'growth' ? '/records/growth' : null,
        builder: (c, s) => RecordsScreen(
          initialDate: _parseRouteDateOrToday(s.uri.queryParameters['date']),
        ),
      ),
      GoRoute(
        path: '/records/all',
        builder: (c, s) => const AllRecordsScreen(),
      ),
      GoRoute(
        path: '/records/growth',
        builder: (c, s) => const GrowthRecordsScreen(),
      ),
      GoRoute(
        path: '/records/meal/new',
        builder: (c, s) => MealRecordScreen(
          initialDate: _parseRouteDateOrToday(s.uri.queryParameters['date']),
        ),
      ),
      GoRoute(
        path: '/records/expense/new',
        builder: (c, s) => const ExpenseAddScreen(),
      ),
      GoRoute(path: '/wallet', builder: (c, s) => const ExpenseWalletScreen()),
      GoRoute(
        path: '/wallet/report',
        builder: (c, s) => const ExpenseReportScreen(),
      ),
      GoRoute(
        path: '/records/:typeId/new',
        builder: (c, s) => RecordCategoryFormScreen(
          typeId: s.pathParameters['typeId']!,
          initialDate: _parseRouteDateOrToday(s.uri.queryParameters['date']),
        ),
      ),
      GoRoute(
        path: '/records/:recordId/edit',
        builder: (c, s) =>
            RecordEditScreen(recordId: s.pathParameters['recordId']!),
      ),
      GoRoute(
        path: '/records/:recordId',
        builder: (c, s) =>
            RecordDetailScreen(recordId: s.pathParameters['recordId']!),
      ),
      GoRoute(path: '/routine', builder: (c, s) => const RoutineScreen()),
      GoRoute(
        path: '/routine/new',
        builder: (c, s) => const RoutineCreateScreen(),
      ),
      GoRoute(
        path: '/routine/schedule/new',
        builder: (c, s) => const RoutineScheduleCreateScreen(),
      ),
      GoRoute(path: '/community/write', builder: (c, s) => const WriteScreen()),
      GoRoute(
        path: '/pet/:id',
        builder: (c, s) => PetDetailScreen(petId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pet/:id/edit',
        builder: (c, s) => PetEditScreen(petId: s.pathParameters['id']!),
      ),
    ],
  );
});

final _routeDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

DateTime _parseRouteDateOrToday(String? raw) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (raw == null || !_routeDatePattern.hasMatch(raw)) {
    return today;
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return today;
  }

  final date = DateTime(parsed.year, parsed.month, parsed.day);
  return _routeDate(date) == raw ? date : today;
}

String _routeDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
