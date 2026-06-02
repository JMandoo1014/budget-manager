import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../constants/app_categories.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../utils/ai_cache.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../services/storage_service.dart';
import '../utils/category.dart' as cat;
import '../utils/format.dart';
import '../widgets/app_toast.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  List<Expense> _expenses = [];
  List<Income> _incomes = [];
  Map<DateTime, int> _dailyTotals = {};
  Map<DateTime, int> _dailyIncomes = {};
  bool _isLoading = true;

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now;
    _selectedDay = DateTime(now.year, now.month, now.day);
    _loadMonth(now);
  }

  Future<void> _loadMonth(DateTime month) async {
    setState(() => _isLoading = true);
    try {
      final expensesFuture = StorageService().getExpenses(month: month.month, year: month.year);
      final incomesFuture = StorageService().getIncomes(month: month.month, year: month.year);
      final expenses = await expensesFuture;
      List<Income> incomes = [];
      try { incomes = await incomesFuture; } catch (_) {}

      final totals = <DateTime, int>{};
      for (final e in expenses) {
        final key = _normalizeDate(e.createdAt);
        totals[key] = (totals[key] ?? 0) + e.amount;
      }
      final incomeTotals = <DateTime, int>{};
      for (final i in incomes) {
        final key = _normalizeDate(i.createdAt);
        incomeTotals[key] = (incomeTotals[key] ?? 0) + i.amount;
      }
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _incomes = incomes;
          _dailyTotals = totals;
          _dailyIncomes = incomeTotals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Expense> get _selectedExpenses {
    return _expenses
        .where((e) => _normalizeDate(e.createdAt) == _selectedDay)
        .toList();
  }

  List<Income> get _selectedIncomes {
    return _incomes
        .where((i) => _normalizeDate(i.createdAt) == _selectedDay)
        .toList();
  }

  String _formatCompact(int amount) {
    if (amount >= 10000) {
      if (amount % 10000 == 0) return '${amount ~/ 10000}만';
      return '${(amount / 10000).toStringAsFixed(1)}만';
    }
    if (amount >= 1000) {
      if (amount % 1000 == 0) return '${amount ~/ 1000}천';
      return '${(amount / 1000).toStringAsFixed(1)}천';
    }
    return '$amount';
  }

  String get _selectedDateLabel {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[_selectedDay.weekday - 1];
    return '${_selectedDay.month}월 ${_selectedDay.day}일 ($weekday)';
  }

  void _recalculateTotals() {
    final totals = <DateTime, int>{};
    for (final e in _expenses) {
      final key = _normalizeDate(e.createdAt);
      totals[key] = (totals[key] ?? 0) + e.amount;
    }
    _dailyTotals = totals;
    final incomeTotals = <DateTime, int>{};
    for (final i in _incomes) {
      final key = _normalizeDate(i.createdAt);
      incomeTotals[key] = (incomeTotals[key] ?? 0) + i.amount;
    }
    _dailyIncomes = incomeTotals;
  }

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

  Future<void> _deleteExpense(Expense expense) async {
    final idx = _expenses.indexOf(expense);
    setState(() {
      _expenses.remove(expense);
      _recalculateTotals();
    });
    try {
      await StorageService().deleteExpense(expense.id);
      await AiCache.invalidateAll();
      if (mounted) AppToast.show(context, '지출이 삭제됐어요.');
    } catch (_) {
      if (mounted) {
        setState(() {
          _expenses.insert(idx, expense);
          _recalculateTotals();
        });
        AppToast.show(context, AppStrings.deleteFailed, isError: true);
      }
    }
  }

  Future<void> _updateExpense(Expense expense, int amount, String category) async {
    final idx = _expenses.indexOf(expense);
    final updated = Expense(
      id: expense.id,
      rawInput: expense.rawInput,
      category: category,
      amount: amount,
      createdAt: expense.createdAt,
    );
    setState(() {
      _expenses[idx] = updated;
      _recalculateTotals();
    });
    try {
      await StorageService().updateExpense(updated);
      await AiCache.invalidateAll();
      if (mounted) AppToast.show(context, AppStrings.updated);
    } catch (_) {
      if (mounted) {
        setState(() {
          _expenses[idx] = expense;
          _recalculateTotals();
        });
        AppToast.show(context, AppStrings.updateFailed, isError: true);
      }
    }
  }

  Future<void> _deleteIncome(Income income) async {
    final idx = _incomes.indexOf(income);
    setState(() {
      _incomes.remove(income);
      _recalculateTotals();
    });
    try {
      await StorageService().deleteIncome(income.id);
      await AiCache.invalidateAll();
      if (mounted) AppToast.show(context, '수입이 삭제됐어요.');
    } catch (_) {
      if (mounted) {
        setState(() {
          _incomes.insert(idx, income);
          _recalculateTotals();
        });
        AppToast.show(context, AppStrings.deleteFailed, isError: true);
      }
    }
  }

  Future<void> _updateIncome(Income income, int amount, String category) async {
    final idx = _incomes.indexOf(income);
    final updated = Income(
      id: income.id,
      rawInput: income.rawInput,
      category: category,
      amount: amount,
      createdAt: income.createdAt,
    );
    setState(() {
      _incomes[idx] = updated;
      _recalculateTotals();
    });
    try {
      await StorageService().updateIncome(updated);
      await AiCache.invalidateAll();
      if (mounted) AppToast.show(context, AppStrings.updated);
    } catch (_) {
      if (mounted) {
        setState(() {
          _incomes[idx] = income;
          _recalculateTotals();
        });
        AppToast.show(context, AppStrings.updateFailed, isError: true);
      }
    }
  }

  void _showIncomeEditSheet(Income income) {
    final formatter = NumberFormat('#,###');
    final amountCtrl = TextEditingController(text: formatter.format(income.amount));
    var selectedCategory = income.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('수입 수정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                onChanged: (v) {
                  final digits = v.replaceAll(',', '').replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.isEmpty) {
                    amountCtrl.value = const TextEditingValue(text: '');
                  } else {
                    final n = int.tryParse(digits);
                    if (n != null) {
                      final formatted = formatter.format(n);
                      amountCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  }
                },
                decoration: InputDecoration(
                  labelText: '금액 (원)',
                  labelStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                  floatingLabelStyle: const TextStyle(color: AppColors.primary, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppCategories.incomeList.map((item) {
                  final selected = selectedCategory == item.$2;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedCategory = item.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primaryLight : AppColors.chipUnselected,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${item.$1} ${item.$2}',
                        style: TextStyle(
                          fontSize: 13,
                          color: selected ? AppColors.primary : Colors.grey,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final digits = amountCtrl.text.replaceAll(',', '');
                    final amount = int.tryParse(digits) ?? 0;
                    if (amount == 0) return;
                    Navigator.pop(ctx);
                    _updateIncome(income, amount, selectedCategory);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(AppStrings.save, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExpenseEditSheet(Expense expense) {
    final formatter = NumberFormat('#,###');
    final amountCtrl = TextEditingController(text: formatter.format(expense.amount));
    var selectedCategory = expense.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('지출 수정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                onChanged: (v) {
                  final digits = v.replaceAll(',', '').replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.isEmpty) {
                    amountCtrl.value = const TextEditingValue(text: '');
                  } else {
                    final n = int.tryParse(digits);
                    if (n != null) {
                      final formatted = formatter.format(n);
                      amountCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  }
                },
                decoration: InputDecoration(
                  labelText: '금액 (원)',
                  labelStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                  floatingLabelStyle: const TextStyle(color: AppColors.primary, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cat.categoryList.map((item) {
                  final selected = selectedCategory == item.$2;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedCategory = item.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primaryLight : AppColors.chipUnselected,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${item.$1} ${item.$2}',
                        style: TextStyle(
                          fontSize: 13,
                          color: selected ? AppColors.primary : Colors.grey,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final digits = amountCtrl.text.replaceAll(',', '');
                    final amount = int.tryParse(digits) ?? 0;
                    if (amount == 0) return;
                    Navigator.pop(ctx);
                    _updateExpense(expense, amount, selectedCategory);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(AppStrings.save, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '지출 달력',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            _buildCalendarCard(),
            _buildExpenseCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TableCalendar(
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
            _loadMonth(focusedDay);
          },
          locale: 'ko_KR',
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          rowHeight: 68,
          eventLoader: (day) {
            final key = _normalizeDate(day);
            final hasExpense = (_dailyTotals[key] ?? 0) > 0;
            final hasIncome = (_dailyIncomes[key] ?? 0) > 0;
            return hasExpense || hasIncome ? [1] : [];
          },
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextFormatter: (date, locale) => '${date.year}년 ${date.month}월',
            titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.primary),
            rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.primary),
            headerPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
            weekendStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
            dowTextFormatter: (date, locale) =>
                ['일', '월', '화', '수', '목', '금', '토'][date.weekday % 7],
          ),
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
            cellMargin: EdgeInsets.all(4),
            todayDecoration: BoxDecoration(color: Colors.transparent),
            todayTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 16),
            selectedDecoration: BoxDecoration(color: Colors.transparent),
            selectedTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
            weekendTextStyle: TextStyle(color: Colors.black87, fontSize: 13),
            defaultTextStyle: TextStyle(color: Colors.black87, fontSize: 13),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              final key = _normalizeDate(day);
              final expense = _dailyTotals[key] ?? 0;
              final income = _dailyIncomes[key] ?? 0;
              return Positioned(
                bottom: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (expense > 0)
                      Text(
                        '-${_formatCompact(expense)}',
                        style: const TextStyle(fontSize: 8, color: AppColors.danger),
                      ),
                    if (income > 0)
                      Text(
                        '+${_formatCompact(income)}',
                        style: const TextStyle(fontSize: 8, color: AppColors.primary),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              _selectedDateLabel,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _buildExpenseList(),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    final expenses = _selectedExpenses;
    final incomes = _selectedIncomes;

    if (expenses.isEmpty && incomes.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('이날은 내역이 없어요 🎉', style: TextStyle(fontSize: 14, color: Colors.grey)),
        ),
      );
    }

    final totalSpent = expenses.fold(0, (sum, e) => sum + e.amount);
    final totalIncome = incomes.fold(0, (sum, i) => sum + i.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        if (expenses.isNotEmpty) ...[
          _buildSectionLabel('지출'),
          ...List.generate(expenses.length, (idx) {
            final e = expenses[idx];
            return Column(
              children: [
                if (idx > 0) const Divider(height: 1, color: AppColors.divider),
                Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete('이 지출을 삭제할까요?'),
                  onDismissed: (_) => _deleteExpense(e),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: AppColors.danger,
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: GestureDetector(
                    onLongPress: () => _showExpenseEditSheet(e),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Text(cat.categoryEmoji(e.category), style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.rawInput, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(e.category, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text('${formatNumber(e.amount)}원',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
        if (incomes.isNotEmpty) ...[
          SizedBox(height: expenses.isEmpty ? 0 : 8),
          _buildSectionLabel('수입'),
          ...List.generate(incomes.length, (idx) {
            final i = incomes[idx];
            return Column(
              children: [
                if (idx > 0) const Divider(height: 1, color: AppColors.divider),
                Dismissible(
                  key: ValueKey('income_${i.id}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete('이 수입을 삭제할까요?'),
                  onDismissed: (_) => _deleteIncome(i),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: AppColors.danger,
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: GestureDetector(
                    onLongPress: () => _showIncomeEditSheet(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Text(cat.incomeEmoji(i.category), style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i.rawInput, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(i.category, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text('+${formatNumber(i.amount)}원',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
        const SizedBox(height: 4),
        const Divider(height: 1, color: AppColors.divider),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('총 지출 ${formatNumber(totalSpent)}원',
                  style: const TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w500)),
              const Text(' / ', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text('총 수입 ${formatNumber(totalIncome)}원',
                  style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
    );
  }
}
