import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_toast.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _incomeController = TextEditingController();
  final _savingsController = TextEditingController();
  final _periodController = TextEditingController();

  final _patterns = ["술자리 잦음", "배달 자주", "카페 매일", "쇼핑 많음"];
  final _selectedPatterns = <String>{};
  bool _isLoading = false;
  bool _autoRollover = true;
  String? _incomeError;
  String? _savingsError;

  final _formatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadPreviousPrefs();
  }

  Future<void> _loadPreviousPrefs() async {
    final prefs = await StorageService().loadPreviousBudgetPrefs();
    if (prefs == null || !mounted) return;
    setState(() {
      final goal = prefs['savings_goal'] as int;
      final months = prefs['savings_months'] as int;
      final patterns = List<String>.from(prefs['spending_patterns'] as List);
      _savingsController.text = _formatter.format(goal);
      _periodController.text = months.toString();
      _selectedPatterns.addAll(patterns);
      _autoRollover = prefs['auto_rollover'] as bool;
    });
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _savingsController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  void _showToast(String message) => AppToast.show(context, message);

  void _onNumberChanged(TextEditingController controller, String value) {
    final digits = value.replaceAll(',', '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      controller.value = const TextEditingValue(text: '');
    } else {
      final number = int.tryParse(digits);
      if (number != null) {
        final formatted = _formatter.format(number);
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
    _validateFields();
  }

  void _validateFields() {
    final income = _parseFormatted(_incomeController.text);
    final savings = _parseFormatted(_savingsController.text);

    String? incomeError;
    String? savingsError;

    if (_incomeController.text.isNotEmpty && income == 0) {
      incomeError = '수입을 입력해주세요';
    }
    if (_savingsController.text.isNotEmpty) {
      final months = int.tryParse(_periodController.text.trim()) ?? 0;
      if (savings == 0) {
        savingsError = '저축 목표를 입력해주세요';
      } else if (income > 0 && months > 0 && (savings ~/ months) >= income) {
        savingsError = '월 저축 목표(${_formatter.format(savings ~/ months)}원)가 수입보다 클 수 없어요';
      }
    }

    setState(() {
      _incomeError = incomeError;
      _savingsError = savingsError;
    });
  }

  int _parseFormatted(String text) {
    return int.tryParse(text.replaceAll(',', '')) ?? 0;
  }

  Future<void> _onSubmit() async {
    final income = _parseFormatted(_incomeController.text);
    final savings = _parseFormatted(_savingsController.text);
    final months = int.tryParse(_periodController.text.trim()) ?? 0;

    if (income == 0 || savings == 0) {
      _showToast('모든 항목을 입력해주세요!');
      return;
    }
    if (months == 0) {
      _showToast('목표 기간을 1개월 이상 입력해주세요!');
      return;
    }
    if ((savings ~/ months) >= income) {
      _showToast('월 저축 목표(${_formatter.format(savings ~/ months)}원)가 수입보다 클 수 없어요!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final categoryBudgets = await AiService().generateBudget(
        income: income,
        savingsGoal: savings,
        savingsMonths: months,
        spendingPatterns: _selectedPatterns.toList(),
      );

      final budget = Budget(
        income: income,
        savingsGoal: savings,
        savingsMonths: months,
        spendingPatterns: _selectedPatterns.toList(),
        categoryBudgets: categoryBudgets,
        autoRollover: _autoRollover,
      );

      await StorageService().saveBudget(budget);
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showToast('저장에 실패했어요. 다시 시도해주세요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                '이번 달 설정',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                '수입과 목표를 알려주세요!',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _buildFormattedTextField(
                controller: _incomeController,
                label: '이번 달 수입 (원)',
                errorText: _incomeError,
              ),
              const SizedBox(height: 16),
              _buildFormattedTextField(
                controller: _savingsController,
                label: '저축 목표 (원)',
                errorText: _savingsError,
              ),
              Builder(builder: (context) {
                final savings = _parseFormatted(_savingsController.text);
                final months = int.tryParse(_periodController.text.trim()) ?? 0;
                if (savings == 0 || months == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    '월 저축 목표: ${_formatter.format(savings ~/ months)}원',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              }),
              const SizedBox(height: 16),
              _buildPlainTextField(
                controller: _periodController,
                label: '목표 기간 (개월)',
                onChanged: (_) => _validateFields(),
              ),
              const SizedBox(height: 32),
              const Text(
                '소비 패턴을 선택해주세요!',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _patterns.map(_buildChip).toList(),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => setState(() => _autoRollover = !_autoRollover),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _autoRollover,
                        onChanged: (v) => setState(() => _autoRollover = v ?? true),
                        activeColor: const Color(0xFF1D9E75),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '다음 달에도 같은 예산으로 자동 이월할게요',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D9E75).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1D9E75),
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
                            'AI 예산 짜기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedTextField({
    required TextEditingController controller,
    required String label,
    String? errorText,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
        onChanged: (value) => _onNumberChanged(controller, value),
        decoration: _inputDecoration(label, errorText: errorText),
      ),
    );
  }

  Widget _buildPlainTextField({
    required TextEditingController controller,
    required String label,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        decoration: _inputDecoration(label),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? errorText}) {
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      labelStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Color(0xFF1D9E75), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1D9E75), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE24B4A), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE24B4A), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  Widget _buildChip(String label) {
    final selected = _selectedPatterns.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            _selectedPatterns.remove(label);
          } else {
            _selectedPatterns.add(label);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE1F5EE) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? const Color(0xFF1D9E75) : Colors.grey,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}