import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/app_interaction_style.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.errorText, this.onRetry});

  final String? errorText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandMint,
      bottomNavigationBar: SafeArea(
        child: TextButton(
          onPressed: () => context.push('/my/policies'),
          child: const Text('이용약관 · 개인정보 처리방침'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/brand_logo_splash.png',
                  width: 168,
                  height: 168,
                  fit: BoxFit.contain,
                  semanticLabel: '포마펫 시작 화면 로고',
                ),
                const SizedBox(height: 16),
                const Text(
                  '포마펫',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                    child: const Text('다시 시도'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
