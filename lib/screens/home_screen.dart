import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Budget? _budget;
  bool _isLoading = true;

  static const _categoryMeta = {
    '식비': ('🍚', Color(0xFF1D9E75)),
    '술': ('🍺', Color(0xFFE24B4A)),
    '교통': ('🚌', Color(0xFF1D9E75)),
    '카페': ('☕', Color(0xFFEF9F27)),
    '쇼핑': ('🛍', Color(0xFF534AB7)),
    '기타': ('📦', Color(0xFF9E9E9E)),
  };

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final budget = await StorageService().getCurrentBudget();
    if (mounted) {
      setState(() {
        _budget = budget;
        _isLoading = false;
      });
    }
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  String _monthLabel() {
    final now = DateTime.now();
    return '${now.month}월 현황';
  }

  String _daysLeft() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return '${lastDay.day - now.day + 1}일 남음';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _monthLabel(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            Text(
              _daysLeft(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _budget == null
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text(
        '이번 달 예산이 없어\n온보딩에서 설정해줘',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
    );
  }

  Widget _buildContent() {
    final budget = _budget!;
    // 지출 데이터가 없으므로 spent는 0으로 처리
    final totalBudget = budget.totalBudget;
    final remaining = budget.remainingBudget;
    final usedRatio = totalBudget > 0
        ? (totalBudget - remaining) / totalBudget
        : 0.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainBudgetCard(remaining, usedRatio),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '카테고리별',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          ...budget.categoryBudgets.entries.map((entry) {
            final meta = _categoryMeta[entry.key];
            final emoji = meta?.$1 ?? '📌';
            final color = meta?.$2 ?? const Color(0xFF9E9E9E);
            return _buildCategoryCard(emoji, entry.key, 0, entry.value, 0.0, color);
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMainBudgetCard(int remaining, double usedRatio) {
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
          Text(
            '${_formatNumber(remaining)}원',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF534AB7),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedRatio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFEEEDFE),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF534AB7)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(usedRatio * 100).toStringAsFixed(0)}% 사용',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
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
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
