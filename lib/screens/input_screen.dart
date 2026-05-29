import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/expense.dart';
import '../services/storage_service.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _controller = TextEditingController();
  String _input = '';
  String _category = '기타';
  bool _isLoading = false;

  static const _categories = [
    ('🍚', '식비'),
    ('🍺', '술'),
    ('🚌', '교통'),
    ('☕', '카페'),
    ('🛍', '쇼핑'),
    ('📦', '기타'),
  ];

  static const _warningCategories = {'술', '카페'};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasInput => _input.trim().isNotEmpty;
  bool get _showWarning => _warningCategories.contains(_category);

  String get _categoryEmoji =>
      _categories.firstWhere((e) => e.$2 == _category, orElse: () => ('📦', '기타')).$1;

  // rawInput에서 숫자 추출 (마지막 숫자 덩어리를 금액으로 사용)
  int get _extractedAmount {
    final matches = RegExp(r'\d+').allMatches(_input.replaceAll(',', ''));
    if (matches.isEmpty) return 0;
    return int.tryParse(matches.last.group(0)!) ?? 0;
  }

  String get _formattedAmount {
    final amount = _extractedAmount;
    if (amount == 0) return '0원';
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
  }

  Future<void> _onSave() async {
    final amount = _extractedAmount;
    if (amount == 0) {
      _showToast('금액을 확인해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final expense = Expense(
        rawInput: _input.trim(),
        category: _category,
        amount: amount,
      );
      await StorageService().saveExpense(expense);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showToast('저장에 실패했습니다.');
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF534AB7), fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        elevation: 4,
      ),
    );
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
                children: _categories.map((cat) {
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
                            ? const Color(0xFFEEEDFE)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${cat.$1} ${cat.$2}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? const Color(0xFF534AB7) : Colors.grey,
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
      backgroundColor: Colors.white,
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
                    if (_showWarning) ...[
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
      onChanged: (value) => setState(() => _input = value),
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
          borderSide: const BorderSide(color: Color(0xFF534AB7)),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('카테고리', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEDFE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_categoryEmoji $_category',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF534AB7),
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
                style: TextStyle(fontSize: 12, color: Color(0xFF534AB7)),
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
        color: const Color(0xFFEEEDFE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              '⚠ 이 카테고리 예산을 많이 썼어요. 지출을 확인해보세요.',
              style: TextStyle(fontSize: 12, color: Color(0xFF534AB7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      child: Opacity(
        opacity: _hasInput ? 1.0 : 0.4,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _hasInput && !_isLoading ? _onSave : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF534AB7),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF534AB7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
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
