import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/shell_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/input_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await StorageService().init();
  await NotificationService().init();
  await PurchaseService().init();
  final budget = await StorageService().getCurrentBudget();
  final initialLocation = budget != null ? '/home' : '/';
  runApp(BudgetManagerApp(initialLocation: initialLocation));
}

class BudgetManagerApp extends StatefulWidget {
  const BudgetManagerApp({super.key, required this.initialLocation});

  final String initialLocation;

  @override
  State<BudgetManagerApp> createState() => _BudgetManagerAppState();
}

class _BudgetManagerAppState extends State<BudgetManagerApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/input',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: InputScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CalendarScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analysis',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AnalysisScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '텅장방지',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D9E75),
          brightness: Brightness.light,
        ),
        primaryColor: const Color(0xFF1D9E75),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      routerConfig: _router,
    );
  }
}
