import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'home_screen.dart';
import 'input_screen.dart';
import 'analysis_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late final PageController _pageController;
  double _currentPage = 0;

  static const _tabs = [
    _TabItem(label: '홈', selected: Icons.home_rounded, unselected: Icons.home_outlined),
    _TabItem(label: '입력', selected: Icons.add_circle_rounded, unselected: Icons.add_circle_outline_rounded),
    _TabItem(label: '분석', selected: Icons.bar_chart_rounded, unselected: Icons.bar_chart_outlined),
    _TabItem(label: '설정', selected: Icons.settings_rounded, unselected: Icons.settings_outlined),
  ];

  void _onPageChanged() {
    setState(() => _currentPage = _pageController.page ?? 0);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            children: const [
              HomeScreen(),
              InputScreen(),
              AnalysisScreen(),
              _SettingsPlaceholder(),
            ],
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  final opacity = (1.0 - (_currentPage - index).abs()).clamp(0.0, 1.0);
                  final isNearSelected = (_currentPage - index).abs() < 0.5;
                  final tab = _tabs[index];

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTabTapped(index),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 선택 배경 (opacity로 페이드 인/아웃)
                            Opacity(
                              opacity: opacity,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEEDFE),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  tab.selected,
                                  color: const Color(0xFF534AB7),
                                  size: 24,
                                ),
                              ),
                            ),
                            // 미선택 아이콘 (반대 opacity)
                            Opacity(
                              opacity: (1.0 - opacity).clamp(0.0, 1.0),
                              child: Icon(
                                tab.unselected,
                                color: const Color(0xFFBBBBBB),
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData selected;
  final IconData unselected;

  const _TabItem({
    required this.label,
    required this.selected,
    required this.unselected,
  });
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('설정')),
    );
  }
}
