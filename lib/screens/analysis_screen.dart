import 'package:flutter/material.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '4월 리포트',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 20),
            _buildSectionLabel('AI 피드백'),
            const SizedBox(height: 8),
            _buildFeedbackBox(),
            const SizedBox(height: 20),
            _buildSectionLabel('예산 초과 카테고리'),
            const SizedBox(height: 8),
            _buildOverBudgetCard('🍺', '술', '+8,000원 초과'),
            const SizedBox(height: 8),
            _buildOverBudgetCard('☕', '카페', '+4,500원 초과'),
            const SizedBox(height: 20),
            _buildSectionLabel('전체 지출 내역'),
            const SizedBox(height: 8),
            _buildExpenseCard('치킨', '식비', '15,000원'),
            const SizedBox(height: 8),
            _buildExpenseCard('지하철', '교통', '1,400원'),
            const SizedBox(height: 8),
            _buildExpenseCard('카페라떼', '카페', '5,500원'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('총 지출', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Text(
                      '287,600원',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('저축 달성률', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Text(
                      '87%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D9E75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0.87,
              minHeight: 8,
              backgroundColor: Color(0xFFE8F5EF),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1D9E75)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDFE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '💡 주말 지출이 평일의 2.3배야. 주말 예산을 따로 잡으면 월 3만원 더 아낄 수 있어.',
        style: TextStyle(fontSize: 13, color: Color(0xFF534AB7), height: 1.5),
      ),
    );
  }

  Widget _buildOverBudgetCard(String emoji, String name, String overAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$emoji $name',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Text(
            overAmount,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE24B4A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(String title, String category, String amount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(category, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          Text(
            amount,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
    );
  }
}
