import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../services/storage_service.dart';
import '../utils/category.dart' as cat;
import '../utils/format.dart';
import '../widgets/app_toast.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int _tabIndex = 0;
  Budget? _budget;
  List<Expense> _expenses = [];
  List<Income> _incomes = [];
  bool _isLoading = true;
  bool _hasError = false;

  final _dateFormat = DateFormat('MM/dd HH:mm');

  static const _incomeCategoryList = [
    ('💼', '알바'),
    ('💰', '용돈'),
    ('💵', '기타수입'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final now = DateTime.now();
      final budget = await StorageService().getCurrentBudget();
      final expenses = await StorageService().getExpenses(month: now.month, year: now.year);
      List<Income> incomes = [];
      try {
        incomes = await StorageService().getIncomes(month: now.month, year: now.year);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _budget = budget;
          _expenses = expenses;
          _incomes = incomes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  // ── 공통 ──────────────────────────────────────────────
  Future<bool> _confirmDelete(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Color(0xFFE24B4A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ── 지출 CRUD ──────────────────────────────────────────
  Future<void> _deleteExpense(Expense expense) async {
    setState(() => _expenses.removeWhere((e) => e.id == expense.id));
    try {
      await StorageService().deleteExpense(expense.id);
      if (mounted) AppToast.show(context, '지출이 삭제됐어요.');
    } catch (_) {
      if (mounted) {
        setState(() => _expenses.insert(0, expense));
        AppToast.show(context, '삭제에 실패했어요.', isError: true);
      }
    }
  }

  Future<void> _updateExpense(Expense expense, int amount, String category) async {
    final updated = Expense(
      id: expense.id,
      rawInput: expense.rawInput,
      category: category,
      amount: amount,
      createdAt: expense.createdAt,
      memo: expense.memo,
    );
    setState(() {
      final idx = _expenses.indexWhere((e) => e.id == expense.id);
      if (idx != -1) _expenses[idx] = updated;
    });
    try {
      await StorageService().updateExpense(updated);
      if (mounted) AppToast.show(context, '수정됐어요.');
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _expenses.indexWhere((e) => e.id == updated.id);
          if (idx != -1) _expenses[idx] = expense;
        });
        AppToast.show(context, '수정에 실패했어요.', isError: true);
      }
    }
  }

  void _showExpenseEditSheet(Expense expense) {
    final amountController = TextEditingController(text: expense.amount.toString());
    String selectedCategory = expense.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('지출 수정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '금액',
                  suffixText: '원',
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1D9E75)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('카테고리', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cat.categoryList.map((item) {
                  final isSelected = selectedCategory == item.$2;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedCategory = item.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE1F5EE) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${item.$1} ${item.$2}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? const Color(0xFF1D9E75) : Colors.grey,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final amount = int.tryParse(amountController.text) ?? expense.amount;
                    _updateExpense(expense, amount, selectedCategory);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 수입 CRUD ──────────────────────────────────────────
  Future<void> _deleteIncome(Income income) async {
    setState(() => _incomes.removeWhere((i) => i.id == income.id));
    try {
      await StorageService().deleteIncome(income.id);
      if (mounted) AppToast.show(context, '수입이 삭제됐어요.');
    } catch (_) {
      if (mounted) {
        setState(() => _incomes.insert(0, income));
        AppToast.show(context, '삭제에 실패했어요.', isError: true);
      }
    }
  }

  Future<void> _updateIncome(Income income, int amount, String category) async {
    final updated = Income(
      id: income.id,
      rawInput: income.rawInput,
      category: category,
      amount: amount,
      createdAt: income.createdAt,
      memo: income.memo,
    );
    setState(() {
      final idx = _incomes.indexWhere((i) => i.id == income.id);
      if (idx != -1) _incomes[idx] = updated;
    });
    try {
      await StorageService().updateIncome(updated);
      if (mounted) AppToast.show(context, '수정됐어요.');
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _incomes.indexWhere((i) => i.id == updated.id);
          if (idx != -1) _incomes[idx] = income;
        });
        AppToast.show(context, '수정에 실패했어요.', isError: true);
      }
    }
  }

  void _showIncomeEditSheet(Income income) {
    final amountController = TextEditingController(text: income.amount.toString());
    String selectedCategory = income.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('수입 수정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '금액',
                  suffixText: '원',
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1D9E75)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('카테고리', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _incomeCategoryList.map((item) {
                  final isSelected = selectedCategory == item.$2;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedCategory = item.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE1F5EE) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${item.$1} ${item.$2}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? const Color(0xFF1D9E75) : Colors.grey,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final amount = int.tryParse(amountController.text) ?? income.amount;
                    _updateIncome(income, amount, selectedCategory);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 빌드 ──────────────────────────────────────────────
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
          ? _buildSkeleton()
          : _hasError
              ? _buildError()
              : Column(
                  children: [
                    _buildTabSelector(),
                    Expanded(
                      child: _tabIndex == 0
                          ? (_budget == null ? _buildEmpty() : _buildExpenseTab())
                          : _buildIncomeTab(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTabItem('지출', 0),
            _buildTabItem('수입', 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseTab() {
    final budget = _budget!;
    final spentByCategory = <String, int>{};
    for (final e in _expenses) {
      spentByCategory[e.category] = (spentByCategory[e.category] ?? 0) + e.amount;
    }
    final totalSpent = spentByCategory.values.fold(0, (sum, v) => sum + v);
    final actualSavings = (budget.income - totalSpent).clamp(0, budget.income);
    final monthlySavingsGoal = budget.savingsGoal ~/ budget.savingsMonths;
    final achievementRate = monthlySavingsGoal > 0
        ? (actualSavings / monthlySavingsGoal).clamp(0.0, 1.0)
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
          _buildSummaryCard(totalSpent, achievementRate, actualSavings, monthlySavingsGoal),
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
            _buildEmptyBox('이번 달 지출 내역이 없어요! 🎉')
          else
            ..._expenses.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey(e.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDelete('이 지출을 삭제할까요?'),
                    onDismissed: (_) => _deleteExpense(e),
                    background: _dismissBackground(),
                    child: GestureDetector(
                      onLongPress: () => _showExpenseEditSheet(e),
                      child: _buildExpenseCard(e),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildIncomeTab() {
    final totalIncome = _incomes.fold(0, (sum, i) => sum + i.amount);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('이번 달 총 수입', style: TextStyle(fontSize: 13, color: Colors.grey)),
                Text(
                  '${formatNumber(totalIncome)}원',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1D9E75)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionLabel('수입 내역'),
          const SizedBox(height: 8),
          if (_incomes.isEmpty)
            _buildEmptyBox('이번 달 수입 내역이 없어요.')
          else
            ..._incomes.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey(i.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDelete('이 수입을 삭제할까요?'),
                    onDismissed: (_) => _deleteIncome(i),
                    background: _dismissBackground(),
                    child: GestureDetector(
                      onLongPress: () => _showIncomeEditSheet(i),
                      child: _buildIncomeCard(i),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _dismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE24B4A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
            '${formatNumber(expense.amount)}원',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeCard(Income income) {
    final emoji = switch (income.category) {
      '알바' => '💼',
      '용돈' => '💰',
      _ => '💵',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$emoji  ${income.rawInput}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${income.category}  •  ${_dateFormat.format(income.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '+${formatNumber(income.amount)}원',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1D9E75)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    const grey = Color(0xFFE8E8E8);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 120, decoration: BoxDecoration(color: grey, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 20),
          Container(width: 70, height: 14, decoration: BoxDecoration(color: grey, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          Container(height: 60, decoration: BoxDecoration(color: grey, borderRadius: BorderRadius.circular(12))),
          const SizedBox(height: 20),
          Container(width: 100, height: 14, decoration: BoxDecoration(color: grey, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          ...List.generate(3, (i) => Container(
            height: 68,
            margin: const EdgeInsets.only(bottom: 8),
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
            const Text('데이터를 불러오지 못했어요.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('이번 달 예산을 설정해주세요!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _buildSummaryCard(int totalSpent, double achievementRate, int actualSavings, int savingsGoal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
                    Text('${formatNumber(totalSpent)}원', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1D9E75)),
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
              '실제 저축: ${formatNumber(actualSavings)}원 / 목표: ${formatNumber(savingsGoal)}원',
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
      decoration: BoxDecoration(color: const Color(0xFFE1F5EE), borderRadius: BorderRadius.circular(12)),
      child: const Text(
        '💡 이번 달 지출 패턴을 분석 중이에요. AI 연동 후 맞춤 피드백을 드릴게요!',
        style: TextStyle(fontSize: 13, color: Color(0xFF1D9E75), height: 1.5),
      ),
    );
  }

  Widget _buildOverBudgetCard(String category, int overAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Text(
            '+${formatNumber(overAmount)}원 초과',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE24B4A)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
    );
  }

  Widget _buildInfoBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Text(message, style: const TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87));
  }
}
