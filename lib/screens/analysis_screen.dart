import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  Budget? _budget;
  List<Expense> _expenses = [];
  bool _isLoading = true;

  final _dateFormat = DateFormat('MM/dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadData();
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

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${DateTime.now().month}월 리포트',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
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
        '이번 달 예산을 설정해주세요!',
        style: TextStyle(color: Colors.grey, fontSize: 14),
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
    final actualSavings = (budget.income - totalSpent).clamp(0, budget.income);
    final achievementRate = budget.savingsGoal > 0
        ? (actualSavings / budget.savingsGoal).clamp(0.0, 1.0)
        : 0.0;

    final overBudgetEntries = budget.categoryBudgets.entries
        .where((e) => (spentByCategory[e.key] ?? 0) > e.value)
        .toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(totalSpent, achievementRate, actualSavings, budget.savingsGoal),
          const SizedBox(height: 20),
          _buildSectionLabel('AI 피드백'),
          const SizedBox(height: 8),
          _buildFeedbackBox(),
          const SizedBox(height: 20),
          _buildSectionLabel('예산 초과 카테고리'),
          const SizedBox(height: 8),
          if (overBudgetEntries.isEmpty)
            _buildInfoBox('이번 달은 모든 카테고리 예산을 지켰어요! 🎉')
          else
            ...overBudgetEntries.map((e) {
              final over = (spentByCategory[e.key] ?? 0) - e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildOverBudgetCard(e.key, over),
              );
            }),
          const SizedBox(height: 20),
          _buildSectionLabel('전체 지출 내역'),
          const SizedBox(height: 8),
          if (_expenses.isEmpty)
            _buildInfoBox('아직 지출 내역이 없어요.')
          else
            ..._expenses.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildExpenseCard(e),
                )),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int totalSpent, double achievementRate, int actualSavings, int savingsGoal) {
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
                    Text(
                      '${_formatNumber(totalSpent)}원',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    Text(
                      '${(achievementRate * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
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
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '실제 저축: ${_formatNumber(actualSavings)}원 / 목표: ${_formatNumber(savingsGoal)}원',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: achievementRate,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8F5EF),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1D9E75)),
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
        '💡 이번 달 지출 패턴을 분석 중이에요. AI 연동 후 맞춤 피드백을 드릴게요!',
        style: TextStyle(fontSize: 13, color: Color(0xFF534AB7), height: 1.5),
      ),
    );
  }

  Widget _buildOverBudgetCard(String category, int overAmount) {
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
            category,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Text(
            '+${_formatNumber(overAmount)}원 초과',
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

  Widget _buildExpenseCard(Expense expense) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.rawInput,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${expense.category}  •  ${_dateFormat.format(expense.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_formatNumber(expense.amount)}원',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
        textAlign: TextAlign.center,
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
