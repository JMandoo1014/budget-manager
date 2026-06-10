import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_categories.dart';
import '../constants/app_colors.dart';
import '../utils/ai_cache.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/category.dart' as cat;
import '../utils/format.dart';
import '../widgets/app_tab_selector.dart';
import '../widgets/app_toast.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  int _tabIndex = 0;

  // 지출 상태
  final _expenseController = TextEditingController();
  Timer? _debounceTimer;
  int _classifyGeneration = 0;
  String _input = '';
  String _category = '기타';
  int _amount = 0;
  String _name = '';
  bool _isClassifying = false;
  bool _isSaving = false;

  // 수입 상태
  final _incomeController = TextEditingController();
  Timer? _incomeDebounceTimer;
  int _incomeClassifyGeneration = 0;
  String _incomeInput = '';
  String _incomeCategory = '기타수입';
  int _incomeAmount = 0;
  String _incomeName = '';
  bool _isClassifyingIncome = false;
  bool _isSavingIncome = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _incomeDebounceTimer?.cancel();
    _expenseController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  // ── 지출 ──────────────────────────────────────────────
  bool get _hasInput => _input.trim().isNotEmpty;
  bool get _showWarning => AppCategories.warningCategories.contains(_category);
  String get _categoryEmoji => cat.categoryEmoji(_category);
  String get _formattedAmount => _amount == 0 ? '0원' : '${formatNumber(_amount)}원';

  void _onInputChanged(String value) {
    setState(() => _input = value);
    _debounceTimer?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _category = '기타';
        _amount = 0;
        _name = '';
        _isClassifying = false;
      });
      return;
    }

    final generation = ++_classifyGeneration;
    setState(() => _isClassifying = true);
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      final result = await AiService().classifyExpense(value.trim());
      if (mounted && generation == _classifyGeneration) {
        setState(() {
          _category = result['category'] as String? ?? '기타';
          _amount = (result['amount'] as num?)?.toInt() ?? 0;
          _name = result['name'] as String? ?? value.trim();
          _isClassifying = false;
        });
      }
    });
  }

  Future<void> _onSave() async {
    if (_amount == 0) {
      AppToast.show(context, '금액을 확인해주세요.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final expense = Expense(
        rawInput: _name.isNotEmpty ? _name : _input.trim(),
        category: _category,
        amount: _amount,
      );
      await StorageService().saveExpense(expense);
      await _checkAndNotifyOverBudget(expense.category);
      await AiCache.invalidateAll();
      if (mounted) {
        HapticFeedback.lightImpact();
        _expenseController.clear();
        setState(() {
          _input = '';
          _category = '기타';
          _amount = 0;
          _name = '';
          _isClassifying = false;
          _isSaving = false;
        });
        AppToast.show(context, '지출이 기록됐어요! 💰');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.show(context, '저장에 실패했어요.', isError: true);
      }
    }
  }

  Future<void> _checkAndNotifyOverBudget(String category) async {
    try {
      final now = DateTime.now();
      final budget = await StorageService().getCurrentBudget();
      if (budget == null) return;
      final limit = budget.categoryBudgets[category];
      if (limit == null) return;

      final expenses = await StorageService().getExpenses(month: now.month, year: now.year);
      final totalSpent = expenses
          .where((e) => e.category == category)
          .fold(0, (sum, e) => sum + e.amount);

      if (totalSpent > limit) {
        await NotificationService().showOverBudgetNotification(category, totalSpent - limit);
      }
    } catch (_) {}
  }

  void _showCategorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('카테고리 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cat.categoryList.map((item) {
                  final isSelected = _category == item.$2;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _category = item.$2);
                      Navigator.pop(context);
                    },
                    child: _buildChip(item.$1, item.$2, isSelected),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── 수입 ──────────────────────────────────────────────
  bool get _hasIncomeInput => _incomeInput.trim().isNotEmpty;
  String get _incomeCategoryEmoji => cat.incomeEmoji(_incomeCategory);
  String get _formattedIncomeAmount => _incomeAmount == 0 ? '0원' : '${formatNumber(_incomeAmount)}원';

  void _onIncomeInputChanged(String value) {
    setState(() => _incomeInput = value);
    _incomeDebounceTimer?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _incomeCategory = '기타수입';
        _incomeAmount = 0;
        _incomeName = '';
        _isClassifyingIncome = false;
      });
      return;
    }

    final generation = ++_incomeClassifyGeneration;
    setState(() => _isClassifyingIncome = true);
    _incomeDebounceTimer = Timer(const Duration(milliseconds: 800), () async {
      final result = await AiService().classifyIncome(value.trim());
      if (mounted && generation == _incomeClassifyGeneration) {
        setState(() {
          _incomeCategory = result['category'] as String? ?? '기타수입';
          _incomeAmount = (result['amount'] as num?)?.toInt() ?? 0;
          _incomeName = result['name'] as String? ?? value.trim();
          _isClassifyingIncome = false;
        });
      }
    });
  }

  Future<void> _onSaveIncome() async {
    if (_incomeAmount == 0) {
      AppToast.show(context, '금액을 확인해주세요.');
      return;
    }

    setState(() => _isSavingIncome = true);

    try {
      final income = Income(
        rawInput: _incomeName.isNotEmpty ? _incomeName : _incomeInput.trim(),
        category: _incomeCategory,
        amount: _incomeAmount,
      );
      await StorageService().saveIncome(income);
      await AiCache.invalidateAll();
      if (mounted) {
        HapticFeedback.lightImpact();
        _incomeController.clear();
        setState(() {
          _incomeInput = '';
          _incomeCategory = '기타수입';
          _incomeAmount = 0;
          _incomeName = '';
          _isClassifyingIncome = false;
          _isSavingIncome = false;
        });
        AppToast.show(context, '수입이 기록됐어요! 💵');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSavingIncome = false);
        AppToast.show(context, '저장에 실패했어요.', isError: true);
      }
    }
  }

  void _showIncomeCategorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('카테고리 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppCategories.incomeList.map((item) {
                  final isSelected = _incomeCategory == item.$2;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _incomeCategory = item.$2);
                      Navigator.pop(context);
                    },
                    child: _buildChip(item.$1, item.$2, isSelected),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String emoji, String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight : AppColors.chipUnselected,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(
          fontSize: 14,
          color: isSelected ? AppColors.primary : Colors.grey,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  // ── 빌드 ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '입력',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: AppTabSelector(
              tabs: const ['지출', '수입'],
              selectedIndex: _tabIndex,
              onTabChanged: (i) => setState(() => _tabIndex = i),
            ),
          ),
          Expanded(
            child: _tabIndex == 0 ? _buildExpenseContent() : _buildIncomeContent(),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildExpenseContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(controller: _expenseController, hint: '치킨 15000', onChanged: _onInputChanged),
          const SizedBox(height: 6),
          const Text(
            '← 이렇게 짧게만 써도 AI가 분류해줘',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (_hasInput) ...[
            const SizedBox(height: 20),
            _buildExpenseResultCard(),
            if (_showWarning && !_isClassifying) ...[
              const SizedBox(height: 12),
              _buildWarningBox(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildIncomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(controller: _incomeController, hint: '알바비 300000', onChanged: _onIncomeInputChanged),
          const SizedBox(height: 6),
          const Text(
            '← 알바비, 용돈 등 받은 돈을 입력해줘',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (_hasIncomeInput) ...[
            const SizedBox(height: 20),
            _buildIncomeResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 18),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 18, color: Colors.grey),
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildExpenseResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _isClassifying
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          : _buildResultRows(
              emoji: _categoryEmoji,
              category: _category,
              formattedAmount: _formattedAmount,
              onEditCategory: _showCategorySheet,
            ),
    );
  }

  Widget _buildIncomeResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _isClassifyingIncome
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          : _buildResultRows(
              emoji: _incomeCategoryEmoji,
              category: _incomeCategory,
              formattedAmount: _formattedIncomeAmount,
              onEditCategory: _showIncomeCategorySheet,
            ),
    );
  }

  Widget _buildResultRows({
    required String emoji,
    required String category,
    required String formattedAmount,
    required VoidCallback onEditCategory,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('카테고리', style: TextStyle(fontSize: 13, color: Colors.grey)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$emoji $category',
                style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('금액', style: TextStyle(fontSize: 13, color: Colors.grey)),
            Text(formattedAmount, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onEditCategory,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '카테고리 수정',
              style: TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningLightBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              '⚠ 이 카테고리 예산을 많이 썼어요. 지출을 확인해보세요.',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final bool canSave;
    final VoidCallback? onPressed;
    final bool isLoading;

    if (_tabIndex == 0) {
      canSave = _hasInput && !_isSaving && !_isClassifying && _amount > 0;
      onPressed = canSave ? _onSave : null;
      isLoading = _isSaving;
    } else {
      canSave = _hasIncomeInput && !_isSavingIncome && !_isClassifyingIncome && _incomeAmount > 0;
      onPressed = canSave ? _onSaveIncome : null;
      isLoading = _isSavingIncome;
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = bottomInset > 0 ? bottomInset + 16 : 100.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPad),
      child: Opacity(
        opacity: canSave ? 1.0 : 0.4,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('기록하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
