import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/services/care_schedule_service.dart';
import 'package:frontend/services/reminder_tap_service.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../support/audit_api.dart';

void main() {
  setUpAll(() {
    initApiClient('https://example.test', includeAuthInterceptor: false);
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  setUp(() => ReminderTapService.instance.reset());
  for (final schedule in [false, true]) {
    testWidgets(
      'deleted ${schedule ? "care schedule" : "routine"} push keeps current screen and explains missing target',
      (tester) async {
        final api = AuditApi(auditDefaultResponse);
        useAuditApi(api);
        final pet = PetNotifier.testWithServices(
          PetState(
            isLoading: false,
            hasOnboarded: true,
            pets: [Pet.fromJson(auditPet('a')), Pet.fromJson(auditPet('b'))],
            activePetId: 'a',
            records: [],
            routines: [],
            todayRoutineItems: [],
            routineCompletions: {},
            quickTypeIds: [],
          ),
          scheduleService: CareScheduleService(),
        );
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('current screen')),
            ),
            GoRoute(
              path: '/routine/:id',
              builder: (_, _) => const Scaffold(body: Text('incorrect detail')),
            ),
            GoRoute(
              path: '/routine/schedule/:id',
              builder: (_, _) => const Scaffold(body: Text('incorrect detail')),
            ),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            routerProvider.overrideWithValue(router),
            authProvider.overrideWith(
              (_) => AuthNotifier.test(
                const AuthState(
                  isLoading: false,
                  isAuthenticated: true,
                  profile: UserProfile(
                    id: 'user-a',
                    email: 'a@example.test',
                    nickname: 'A',
                  ),
                ),
              ),
            ),
            petProvider.overrideWith((_) => pet),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const FormypetApp(),
          ),
        );
        await tester.pumpAndSettle();
        ReminderTapService.instance.receive({
          'type': schedule ? 'CARE_SCHEDULE_REMINDER' : 'ROUTINE_REMINDER',
          'sourceId': '999',
          'messageId': 'deleted-$schedule',
        });
        await tester.pumpAndSettle();
        expect(find.text('연결된 일정 내용을 찾을 수 없어요.'), findsOneWidget);
        expect(find.text('current screen'), findsOneWidget);
        expect(find.text('incorrect detail'), findsNothing);
        expect(pet.state.activePetId, 'a');
        final suffix = schedule ? 'care-schedules' : 'routines';
        expect(
          api.requests.where((r) => r.path.endsWith('/$suffix')).length,
          2,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        router.dispose();
      },
    );
  }
}
