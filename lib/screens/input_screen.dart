import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/expense.dart';
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
  final _controller = TextEditingController();
  Timer? _debounceTimer;
  int _classifyGeneration = 0;

  String _input = '';
  String _category = '기타';
  int _amount = 0;
  String _name = '';
  bool _isClassifying = false;
  bool _isSaving = false;

  static const _warningCategories = {'술', '카페'};

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

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
        _controller.clear();
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
              const Text(
                '카테고리 선택',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cat.categoryList.map((cat) {
                  final isSelected = _category == cat.$2;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _category = cat.$2);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE1F5EE)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${cat.$1} ${cat.$2}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '지출 입력',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputField(),
                  const SizedBox(height: 6),
                  const Text(
                    '← 이렇게 짧게만 써도 AI가 분류해줘',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (_hasInput) ...[
                    const SizedBox(height: 20),
                    _buildResultCard(),
                    if (_showWarning && !_isClassifying) ...[
                      const SizedBox(height: 12),
                      _buildWarningBox(),
                    ],
                  ],
                ],
              ),
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return TextField(
      controller: _controller,
      onChanged: _onInputChanged,
      style: const TextStyle(fontSize: 18),
      decoration: InputDecoration(
        hintText: '치킨 15000',
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

  Widget _buildResultCard() {
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1D9E75),
                  ),
                ),
              ),
            )
          : Column(
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
                        '$_categoryEmoji $_category',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1D9E75),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('금액', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text(
                      _formattedAmount,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showCategorySheet,
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
            ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F5EE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              '⚠ 이 카테고리 예산을 많이 썼어요. 지출을 확인해보세요.',
              style: TextStyle(fontSize: 12, color: Color(0xFF1D9E75)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final canSave = _hasInput && !_isSaving && !_isClassifying && _amount > 0;
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
            onPressed: canSave ? _onSave : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D9E75),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF1D9E75),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    '기록하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }
}
