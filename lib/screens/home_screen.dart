import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '5월 현황',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            Text(
              '28일 남음',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainBudgetCard(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                '카테고리별',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
            _buildCategoryCard('🍚', '식비', 43000, 60000, 0.72, const Color(0xFF1D9E75)),
            _buildCategoryCard('🍺', '술', 28000, 30000, 0.93, const Color(0xFFE24B4A)),
            _buildCategoryCard('🚌', '교통', 12000, 30000, 0.40, const Color(0xFF1D9E75)),
            _buildCategoryCard('☕', '카페', 16000, 20000, 0.80, const Color(0xFFEF9F27)),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF534AB7),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) context.go('/input');
          if (index == 2) context.go('/analysis');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: '입력'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: '분석'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: '설정'),
        ],
      ),
    );
  }

  Widget _buildMainBudgetCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '남은 예산',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          const Text(
            '127,400원',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF534AB7),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.62,
              minHeight: 8,
              backgroundColor: const Color(0xFFEEEDFE),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF534AB7)),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '62% 사용',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    String emoji,
    String name,
    int spent,
    int limit,
    double progress,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$emoji $name',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_formatNumber(spent)}원 / ${_formatNumber(limit)}원',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
