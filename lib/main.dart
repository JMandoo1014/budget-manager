import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/input_screen.dart';
import 'screens/analysis_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/input',
      builder: (context, state) => const InputScreen(),
    ),
    GoRoute(
      path: '/analysis',
      builder: (context, state) => const AnalysisScreen(),
    ),
  ],
);

void main() {
  runApp(const BudgetManagerApp());
}

class BudgetManagerApp extends StatelessWidget {
  const BudgetManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Budget Manager',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF534AB7),
          brightness: Brightness.light,
        ),
        primaryColor: const Color(0xFF534AB7),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
