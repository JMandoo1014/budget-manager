import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
  bool _hasError = false;

  final _dateFormat = DateFormat('MM/dd HH:mm');

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
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
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
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
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
          ? _buildSkeleton()
          : _hasError
              ? _buildError()
              : _budget == null
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: const Color(0xFF1D9E75),
                      child: _buildContent(),
                    ),
    );
  }

  Widget _buildSkeleton() {
    const grey = Color(0xFFE8E8E8);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 130,
            decoration: BoxDecoration(color: grey, borderRadius: BorderRadius.circular(16)),
          ),
          const SizedBox(height: 20),
          Container(
            width: 70,
            height: 14,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: grey, borderRadius: BorderRadius.circular(4)),
          ),
          ...List.generate(5, (i) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: grey, borderRadius: BorderRadius.circular(12)),
          )),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😢', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text(
              '데이터를 불러오지 못했어요.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text('다시 시도해주세요.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
                child: const Text('다시 시도', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💰', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              const Text(
                '이번 달 예산을 설정해주세요!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                '수입과 저축 목표를 입력하면\nAI가 예산을 짜드려요',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
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
            final categoryExpenses = _expenses.where((e) => e.category == entry.key).toList();
            return _buildCategoryCard(emoji, entry.key, spent, limit, color, categoryExpenses);
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

  Widget _buildCategoryCard(String emoji, String name, int spent, int limit, Color color, List<Expense> expenses) {
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isOver = spent > limit;
    return GestureDetector(
      onTap: () => _showCategoryDetail(name, emoji, spent, limit, expenses),
      child: Container(
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
                Row(
                  children: [
                    Text(
                      '$emoji $name',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    if (isOver) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE24B4A)),
                    ],
                  ],
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
      ),
    );
  }

  void _showCategoryDetail(String name, String emoji, int spent, int limit, List<Expense> expenses) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$emoji $name',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${formatNumber(spent)}원 / ${formatNumber(limit)}원',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (expenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('지출 내역이 없어요.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: expenses.length,
                    separatorBuilder: (context, idx) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = expenses[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.rawInput,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis),
                                  Text(_dateFormat.format(e.createdAt),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('${formatNumber(e.amount)}원',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
