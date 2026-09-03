import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'core/api_client.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final baseUrl = kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080';
  initApiClient(baseUrl);
  await KakaoSdk.init(nativeAppKey: 'c5884b48709cf440cd9cf604168ba0cb');

  runApp(const ProviderScope(child: FormypetApp()));
}

class FormypetApp extends ConsumerWidget {
  const FormypetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '포마펫',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8A65)),
        textTheme: GoogleFonts.notoSansKrTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
