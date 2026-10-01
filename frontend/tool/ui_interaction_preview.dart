// Local visual QA only: actual screens/theme, in-memory data, no API writes.
// flutter run -d web-server --web-port 5359 -t tool/ui_interaction_preview.dart
// /?screen=meal|poop|schedule|pet|budget&width=390&scale=1
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/providers/wallet_budget_provider.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/services/wallet_expense_service.dart';
import 'package:frontend/screens/records/meal_record_screen.dart';
import 'package:frontend/screens/records/record_category_form_screen.dart';
import 'package:frontend/screens/routine/routine_schedule_create_screen.dart';
import 'package:frontend/screens/pet/pet_profile_form.dart';
import 'package:frontend/screens/wallet/wallet_budget_screen.dart';
import 'package:frontend/core/api_client.dart';
import 'package:dio/dio.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initApiClient('http://127.0.0.1:1', includeAuthInterceptor: false);
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        handler.reject(
          DioException(
            requestOptions: request,
            error: 'Visual preview: API requests are disabled.',
          ),
        );
      },
    ),
  );
  final query = Uri.base.queryParameters;
  final width = double.tryParse(query['width'] ?? '') ?? 390;
  final scale = double.tryParse(query['scale'] ?? '') ?? 1;
  final screen = switch (query['screen']) {
    'poop' => const RecordCategoryFormScreen(typeId: 'poop'),
    'schedule' => const RoutineScheduleCreateScreen(),
    'pet' => const PetProfileForm(),
    'budget' => WalletBudgetScreen(
      month: DateTime(2026, 9),
      identity: const ('preview', 0),
    ),
    _ => const MealRecordScreen(),
  };
  runApp(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.test(
            const AuthState(isLoading: false, isAuthenticated: true),
          ),
        ),
        petProvider.overrideWith(
          (ref) => PetNotifier.test(
            const PetState(
              isLoading: false,
              hasOnboarded: true,
              pets: [
                Pet(
                  id: 'preview-pet',
                  name: '몽실이',
                  species: 'dog',
                  birthDate: '2022-03-15',
                  accentColor: '#F4A460',
                  bgLight: '#FFF8F0',
                ),
              ],
              activePetId: 'preview-pet',
              records: [],
              routines: [],
              todayRoutineItems: [],
              routineCompletions: {},
              quickTypeIds: [],
            ),
          ),
        ),
        walletBudgetIdentityProvider.overrideWithValue(const ('preview', 0)),
        walletMonthlyBudgetProvider.overrideWith((ref, month) async => 120000),
        walletBudgetExpenseProvider.overrideWith((ref, month) => 42000),
        walletExpenseProvider.overrideWith(
          (ref) => WalletExpenseNotifier(WalletExpenseService()),
        ),
      ],
      child: MaterialApp(
        title: 'UI visual QA — no server writes',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) => ColoredBox(
          color: const Color(0xFFE7EBF0),
          child: Center(
            child: SizedBox(
              width: width,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(width, MediaQuery.sizeOf(context).height),
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
            ),
          ),
        ),
        home: screen,
      ),
    ),
  );
}
