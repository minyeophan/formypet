import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/draft_exit_guard.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const _Draft()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('untouched form leaves without confirmation', (tester) async {
    await open(tester);
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('계속 입력'), findsNothing);
  });

  testWidgets('two same-frame back callbacks only leave one clean route', (
    tester,
  ) async {
    await open(tester);
    Navigator.of(
      tester.element(find.byType(_Draft)),
    ).push(MaterialPageRoute<void>(builder: (_) => const _Draft()));
    await tester.pumpAndSettle();
    final state = tester.state<_DraftState>(find.byType(_Draft));
    state.back();
    state.back();
    await tester.pumpAndSettle();
    expect(find.byType(_Draft), findsOneWidget);
    expect(find.text('open'), findsNothing);
  });

  testWidgets('system back and header preserve dirty input until discard', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'draft');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('계속 입력'), findsOneWidget);
    await tester.tap(find.text('계속 입력'));
    await tester.pumpAndSettle();
    expect(find.text('draft'), findsOneWidget);
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
    'pending save blocks navigation and explicit success releases it',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'draft');
      final state = tester.state<_DraftState>(find.byType(_Draft));
      state.setBusy(true);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('draft'), findsOneWidget);
      expect(find.text('계속 입력'), findsNothing);
      state.complete();
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    },
  );
}

class _Draft extends StatefulWidget {
  const _Draft();
  @override
  State<_Draft> createState() => _DraftState();
}

class _DraftState extends State<_Draft> with DraftExitGuardMixin<_Draft> {
  String text = '';
  bool busy = false;
  @override
  bool get hasUnsavedChanges => text.isNotEmpty;
  @override
  bool get isDraftBusy => busy;
  void setBusy(bool value) => setState(() => busy = value);
  Future<void> back() async {
    if (!await confirmDraftExit() || !mounted) return;
    Navigator.pop(context);
  }

  Future<void> complete() async {
    await allowDraftExit();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => protectDraft(
    onExit: back,
    child: Scaffold(
      body: Column(
        children: [
          TextButton(onPressed: back, child: const Text('back')),
          TextField(onChanged: (value) => setState(() => text = value)),
        ],
      ),
    ),
  );
}
