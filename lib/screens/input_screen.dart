import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/expense.dart';
import '../models/income.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/category.dart' as cat;
import '../utils/format.dart';
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

  static const _warningCategories = {'술', '카페'};
  static const _incomeCategories = ['알바', '용돈', '기타수입'];

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
  bool get _showWarning => _warningCategories.contains(_category);
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
    } catch (e) {
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE1F5EE) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${item.$1} ${item.$2}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? const Color(0xFF1D9E75) : Colors.grey,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
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
    } catch (e) {
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
                children: _incomeCategories.map((c) {
                  final isSelected = _incomeCategory == c;
                  final emoji = cat.incomeEmoji(c);
                  return GestureDetector(
                    onTap: () {
                      setState(() => _incomeCategory = c);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE1F5EE) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$emoji $c',
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? const Color(0xFF1D9E75) : Colors.grey,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
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

  // ── 빌드 ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8F8FA),
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
          _buildTabSelector(),
          Expanded(
            child: _tabIndex == 0 ? _buildExpenseContent() : _buildIncomeContent(),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1D9E75)),
        ),
      ),
    );
  }

  Widget _buildExpenseResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _isClassifying
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D9E75)),
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
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _isClassifyingIncome
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D9E75)),
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
                color: const Color(0xFFE1F5EE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$emoji $category',
                style: const TextStyle(fontSize: 13, color: Color(0xFF1D9E75), fontWeight: FontWeight.w600),
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
              style: TextStyle(fontSize: 12, color: Color(0xFF1D9E75)),
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
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              '⚠ 이 카테고리 예산을 많이 썼어요. 지출을 확인해보세요.',
              style: TextStyle(fontSize: 12, color: Color(0xFFEF9F27)),
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
              backgroundColor: const Color(0xFF1D9E75),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF1D9E75),
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
