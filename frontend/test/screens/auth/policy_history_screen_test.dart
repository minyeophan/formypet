import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/auth/policy_acceptance_screen.dart';
import 'package:frontend/services/policy_service.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:google_fonts/google_fonts.dart';

class _PolicyHistoryService extends PolicyService {
  _PolicyHistoryService(this.rows);

  final List<dynamic> rows;

  @override
  Future<List<dynamic>> history() async => rows;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('policy history uses Korean labels and localized timestamps', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policyServiceProvider.overrideWithValue(
            _PolicyHistoryService([
              {
                'action': 'ACCEPTED',
                'document_type': 'terms',
                'document_version': '2026-01',
                'recorded_at': '2026-01-02T03:04:05',
              },
            ]),
          ),
        ],
        child: const MaterialApp(home: PolicyHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.text('이용약관 동의'), findsOneWidget);
    expect(find.text('약관 · 2026-01'), findsOneWidget);
    expect(find.text('2026.01.02 · 03:04'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('policy history shows a concise empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policyServiceProvider.overrideWithValue(_PolicyHistoryService([])),
        ],
        child: const MaterialApp(home: PolicyHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('아직 동의 이력이 없어요'), findsOneWidget);
    expect(find.textContaining('과거 동의를 추정'), findsNothing);
  });

  testWidgets('policy history stays readable on a narrow enlarged screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: ProviderScope(
          overrides: [
            policyServiceProvider.overrideWithValue(
              _PolicyHistoryService([
                {
                  'action': 'ACCEPTED',
                  'document_type': 'privacy',
                  'document_version': '2026-very-long-version',
                  'recorded_at': '2026-01-02T03:04:05',
                },
              ]),
            ),
          ],
          child: const MaterialApp(home: PolicyHistoryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('개인정보 처리방침 · 2026-very-long-version'), findsOneWidget);
    expect(find.text('2026.01.02 · 03:04'), findsOneWidget);
  });
}
