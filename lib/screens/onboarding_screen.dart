import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/budget.dart';
import '../services/storage_service.dart';

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

  @override
  void dispose() {
    _incomeController.dispose();
    _savingsController.dispose();
    _periodController.dispose();
    super.dispose();
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
    final income = int.tryParse(_incomeController.text.trim()) ?? 0;
    final savings = int.tryParse(_savingsController.text.trim()) ?? 0;
    final months = int.tryParse(_periodController.text.trim()) ?? 0;

    if (income == 0 || savings == 0 || months == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해줘')),
      );
      return;
    }

    if (savings >= income) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저축 목표가 수입보다 클 수 없어')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final available = income - savings;
      final categoryBudgets = _allocateBudget(available);

      final budget = Budget(
        income: income,
        savingsGoal: savings,
        savingsMonths: months,
        spendingPatterns: _selectedPatterns.toList(),
        categoryBudgets: categoryBudgets,
      );

      await StorageService().saveBudget(budget);

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
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
                '수입이랑 목표를 알려줘',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _buildTextField(
                controller: _incomeController,
                label: '이번 달 수입 (원)',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _savingsController,
                label: '저축 목표 (원)',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _periodController,
                label: '목표 기간 (개월)',
              ),
              const SizedBox(height: 32),
              const Text(
                '내 소비 패턴',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _patterns.map(_buildChip).toList(),
              ),
              const SizedBox(height: 40),
              SizedBox(
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
                          'AI 예산 짜줘',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF534AB7)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
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
