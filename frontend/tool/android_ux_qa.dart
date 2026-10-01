// Manual companion to integration_test/android_ux_test.dart. Requires a synthetic
// QA account login after installation; never initializes Firebase or Kakao.
// Requires adb reverse tcp:8094 tcp:8094 and the dedicated QA backend.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/main.dart' show FormypetApp;

void main() {
  if (!kDebugMode ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      !const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES')) {
    throw StateError(
      'Only an explicitly opted-in Android debug QA emulator is allowed.',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  initApiClient('http://127.0.0.1:8094');
  runApp(const ProviderScope(child: FormypetApp()));
}
