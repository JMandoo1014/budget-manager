import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../constants/app_categories.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../utils/category.dart' as cat;
import '../utils/format.dart';
import '../widgets/app_tab_selector.dart';
import '../widgets/app_toast.dart';
import '../widgets/budget_summary_card.dart';

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
  String? _aiReport;
  bool _isLoadingReport = false;

  final _dateFormat = DateFormat('MM/dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final now = DateTime.now();
      final budgetFuture = StorageService().getCurrentBudget();
      final expensesFuture = StorageService().getExpenses(month: now.month, year: now.year);
      final incomesFuture = StorageService().getIncomes(month: now.month, year: now.year);
      final budget = await budgetFuture;
      final expenses = await expensesFuture;
      List<Income> incomes = [];
      try { incomes = await incomesFuture; } catch (_) {}
      if (mounted) {
        setState(() {
          _budget = budget;
          _expenses = expenses;
          _incomes = incomes;
          _isLoading = false;
        });
        _loadAiReport();
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _loadAiReport() async {
    if (_budget == null) return;
    setState(() => _isLoadingReport = true);

    final spentByCategory = <String, int>{};
    for (final e in _expenses) {
      spentByCategory[e.category] = (spentByCategory[e.category] ?? 0) + e.amount;
    }
    final totalSpent = spentByCategory.values.fold(0, (sum, v) => sum + v);
    final totalBudget = _budget!.categoryBudgets.values.fold(0, (sum, v) => sum + v);

    try {
      final report = await AiService().generateMonthlyReport(
        totalSpent: totalSpent,
        totalBudget: totalBudget,
        spentByCategory: spentByCategory,
        budgetByCategory: _budget!.categoryBudgets,
      );
      if (mounted) setState(() { _aiReport = report; _isLoadingReport = false; });
    } catch (_) {
      if (mounted) setState(() { _aiReport = null; _isLoadingReport = false; });
    }
  }

  // ── 공통 ──────────────────────────────────────────────
  Future<bool> _confirmDelete(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(AppStrings.delete, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel, style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.delete, style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
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
        AppToast.show(context, AppStrings.deleteFailed, isError: true);
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
      if (mounted) AppToast.show(context, AppStrings.updated);
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _expenses.indexWhere((e) => e.id == updated.id);
          if (idx != -1) _expenses[idx] = expense;
        });
        AppToast.show(context, AppStrings.updateFailed, isError: true);
      }
    }
  }

  void _showExpenseEditSheet(Expense expense) {
    final formatter = NumberFormat('#,###');
    final amountController = TextEditingController(text: formatter.format(expense.amount));
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
              _buildAmountTextField(amountController, formatter),
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
                    child: _buildSheetChip(item.$1, item.$2, isSelected),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _buildSaveButton(() {
                Navigator.pop(ctx);
                final amount = int.tryParse(amountController.text.replaceAll(',', '')) ?? expense.amount;
                _updateExpense(expense, amount, selectedCategory);
              }),
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
        AppToast.show(context, AppStrings.deleteFailed, isError: true);
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
      if (mounted) AppToast.show(context, AppStrings.updated);
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _incomes.indexWhere((i) => i.id == updated.id);
          if (idx != -1) _incomes[idx] = income;
        });
        AppToast.show(context, AppStrings.updateFailed, isError: true);
      }
    }
  }

  void _showIncomeEditSheet(Income income) {
    final formatter = NumberFormat('#,###');
    final amountController = TextEditingController(text: formatter.format(income.amount));
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
              _buildAmountTextField(amountController, formatter),
              const SizedBox(height: 16),
              const Text('카테고리', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppCategories.incomeList.map((item) {
                  final isSelected = selectedCategory == item.$2;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedCategory = item.$2),
                    child: _buildSheetChip(item.$1, item.$2, isSelected),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _buildSaveButton(() {
                Navigator.pop(ctx);
                final amount = int.tryParse(amountController.text.replaceAll(',', '')) ?? income.amount;
                _updateIncome(income, amount, selectedCategory);
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── 공용 시트 위젯 ────────────────────────────────────
  Widget _buildAmountTextField(TextEditingController ctrl, NumberFormat formatter) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
      onChanged: (v) {
        final digits = v.replaceAll(',', '').replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isEmpty) {
          ctrl.value = const TextEditingValue(text: '');
        } else {
          final n = int.tryParse(digits);
          if (n != null) {
            final formatted = formatter.format(n);
            ctrl.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }
        }
      },
      decoration: InputDecoration(
        labelText: '금액',
        suffixText: '원',
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildSheetChip(String emoji, String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight : AppColors.chipUnselected,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(
          fontSize: 13,
          color: isSelected ? AppColors.primary : Colors.grey,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSaveButton(VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: const Text(AppStrings.save, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── 빌드 ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
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
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: AppTabSelector(
                        tabs: const ['지출', '수입'],
                        selectedIndex: _tabIndex,
                        onTabChanged: (i) => setState(() => _tabIndex = i),
                      ),
                    ),
                    Expanded(
                      child: _tabIndex == 0
                          ? (_budget == null ? _buildEmpty() : _buildExpenseTab())
                          : _buildIncomeTab(),
                    ),
                  ],
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
          BudgetSummaryCard(
            totalSpent: totalSpent,
            achievementRate: achievementRate,
            actualSavings: actualSavings,
            savingsGoal: monthlySavingsGoal,
          ),
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
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
        color: AppColors.danger,
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
                  '${cat.incomeEmoji(income.category)}  ${income.rawInput}',
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 120, decoration: BoxDecoration(color: AppColors.skeleton, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 20),
          Container(width: 70, height: 14, decoration: BoxDecoration(color: AppColors.skeleton, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          Container(height: 60, decoration: BoxDecoration(color: AppColors.skeleton, borderRadius: BorderRadius.circular(12))),
          const SizedBox(height: 20),
          Container(width: 100, height: 14, decoration: BoxDecoration(color: AppColors.skeleton, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          ...List.generate(3, (_) => Container(
            height: 68,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: AppColors.skeleton, borderRadius: BorderRadius.circular(12)),
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
            const Text(AppStrings.loadFailed, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(AppStrings.retryPrompt, style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
                child: const Text(AppStrings.retry, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
              const Text(AppStrings.noBudget, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(AppStrings.setup, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackBox() {
    final String text;
    if (_isLoadingReport) {
      text = '💡 AI가 분석 중이에요...';
    } else if (_aiReport != null && _aiReport!.isNotEmpty) {
      text = '💡 $_aiReport';
    } else {
      text = '💡 이번 달 지출 패턴을 분석 중이에요.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.primary, height: 1.5)),
    );
  }

  Widget _buildOverBudgetCard(String category, int overAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Text(
            '+${formatNumber(overAmount)}원 초과',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.danger),
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
