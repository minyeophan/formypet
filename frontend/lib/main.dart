import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/api_client.dart';
import 'router/app_router.dart';

void main() {
  // Android emulator → localhost:8080. Change for physical device or iOS simulator.
  initApiClient('http://10.0.2.2:8080');
  runApp(const ProviderScope(child: PetyilgiApp()));
}

class PetyilgiApp extends ConsumerWidget {
  const PetyilgiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'petyilgi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8A65)),
        textTheme:
            GoogleFonts.notoSansKrTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
