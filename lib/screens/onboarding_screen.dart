import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../services/storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _incomeController = TextEditingController();
  final _savingsController = TextEditingController();
  final _periodController = TextEditingController();

  final _patterns = ["술자리 잦음", "배달 자주", "카페 매일", "쇼핑 많음"];
  final _selectedPatterns = <String>{};
  bool _isLoading = false;

  final _formatter = NumberFormat('#,###');

  // 토스트
  late final AnimationController _toastAnimController;
  late final Animation<Offset> _toastSlide;
  late final Animation<double> _toastOpacity;
  OverlayEntry? _toastEntry;

  @override
  void initState() {
    super.initState();
    _toastAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _toastSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toastAnimController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));
    _toastOpacity = CurvedAnimation(
      parent: _toastAnimController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _toastEntry?.remove();
    _toastAnimController.dispose();
    _incomeController.dispose();
    _savingsController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _showToast(String message) async {
    _toastEntry?.remove();

    _toastEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: 24,
        right: 24,
        bottom: 40,
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _toastSlide,
            child: FadeTransition(
              opacity: _toastOpacity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF534AB7),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_toastEntry!);
    await _toastAnimController.forward(from: 0);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      await _toastAnimController.reverse();
      _toastEntry?.remove();
      _toastEntry = null;
    }
  }

  void _onNumberChanged(TextEditingController controller, String value) {
    final digits = value.replaceAll(',', '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      controller.value = const TextEditingValue(text: '');
      return;
    }
    final number = int.tryParse(digits);
    if (number == null) return;
    final formatted = _formatter.format(number);
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  int _parseFormatted(String text) {
    return int.tryParse(text.replaceAll(',', '')) ?? 0;
  }

  Map<String, int> _allocateBudget(int available) {
    final base = {
      '식비': (available * 0.30).round(),
      '술': (available * 0.15).round(),
      '교통': (available * 0.15).round(),
      '카페': (available * 0.10).round(),
      '쇼핑': (available * 0.15).round(),
    };
    final allocated = base.values.fold(0, (sum, v) => sum + v);
    base['기타'] = available - allocated;
    return base;
  }

  Future<void> _onSubmit() async {
    final income = _parseFormatted(_incomeController.text);
    final savings = _parseFormatted(_savingsController.text);
    final months = int.tryParse(_periodController.text.trim()) ?? 0;

    if (income == 0 || savings == 0 || months == 0) {
      _showToast('모든 항목을 입력해주세요!');
      return;
    }
    if (savings >= income) {
      _showToast('저축 목표가 수입보다 클 수 없어요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final available = income - savings;
      final budget = Budget(
        income: income,
        savingsGoal: savings,
        savingsMonths: months,
        spendingPatterns: _selectedPatterns.toList(),
        categoryBudgets: _allocateBudget(available),
      );

      await StorageService().saveBudget(budget);
      if (mounted) context.go('/home');
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
              ),
              const SizedBox(height: 16),
              _buildFormattedTextField(
                controller: _savingsController,
                label: '저축 목표 (원)',
              ),
              const SizedBox(height: 16),
              _buildPlainTextField(
                controller: _periodController,
                label: '목표 기간 (개월)',
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
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF534AB7).withValues(alpha: 0.3),
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
        decoration: _inputDecoration(label),
      ),
    );
  }

  Widget _buildPlainTextField({
    required TextEditingController controller,
    required String label,
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
        decoration: _inputDecoration(label),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Color(0xFF534AB7), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF534AB7), width: 1.5),
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
          color: selected ? const Color(0xFFEEEDFE) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? const Color(0xFF534AB7) : Colors.grey,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
