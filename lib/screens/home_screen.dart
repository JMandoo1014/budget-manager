import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/budget.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import '../utils/category.dart' as cat;
import '../utils/format.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.refreshTrigger = 0});

  final int refreshTrigger;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Budget? _budget;
  List<Expense> _expenses = [];
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final budgetFuture = StorageService().getCurrentBudget();
    final expensesFuture = StorageService().getExpenses(month: now.month, year: now.year);
    final budget = await budgetFuture;
    final expenses = await expensesFuture;
    if (mounted) {
      setState(() {
        _budget = budget;
        _expenses = expenses;
        _isLoading = false;
      });
    }
  }

  String get _monthLabel => '${DateTime.now().month}월 현황';

  String get _daysLeft {
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
              _monthLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            Text(
              _daysLeft,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '이번 달 예산을 설정해주세요!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('설정하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final budget = _budget!;

    final spentByCategory = <String, int>{};
    for (final e in _expenses) {
      spentByCategory[e.category] = (spentByCategory[e.category] ?? 0) + e.amount;
    }
    final totalSpent = spentByCategory.values.fold(0, (sum, v) => sum + v);
    final totalBudget = budget.totalBudget;
    final remaining = totalBudget - totalSpent;
    final usedRatio = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainBudgetCard(totalBudget, totalSpent, remaining, usedRatio),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '카테고리별',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          ...budget.categoryBudgets.entries.map((entry) {
            final emoji = cat.categoryEmoji(entry.key);
            final limit = entry.value;
            final spent = spentByCategory[entry.key] ?? 0;
            final color = cat.progressColor(spent, limit);
            return _buildCategoryCard(emoji, entry.key, spent, limit, color);
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMainBudgetCard(int totalBudget, int totalSpent, int remaining, double usedRatio) {
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
            '${formatNumber(remaining)}원',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D9E75),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedRatio,
              minHeight: 8,
              backgroundColor: const Color(0xFFE1F5EE),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1D9E75)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(usedRatio * 100).toStringAsFixed(0)}% 사용  •  총 예산 ${formatNumber(totalBudget)}원',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String emoji, String name, int spent, int limit, Color color) {
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
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
                '${formatNumber(spent)}원 / ${formatNumber(limit)}원',
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
}
