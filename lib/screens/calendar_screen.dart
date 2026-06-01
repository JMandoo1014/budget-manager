import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/expense.dart';
import '../services/storage_service.dart';
import '../utils/category.dart' as cat;
import '../utils/format.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  List<Expense> _expenses = [];
  Map<DateTime, int> _dailyTotals = {};
  bool _isLoading = true;

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
      final expenses = await StorageService().getExpenses(
        month: month.month,
        year: month.year,
      );
      final totals = <DateTime, int>{};
      for (final e in expenses) {
        final local = e.createdAt.toLocal();
        final key = DateTime(local.year, local.month, local.day);
        totals[key] = (totals[key] ?? 0) + e.amount;
      }
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _dailyTotals = totals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Expense> get _selectedExpenses {
    return _expenses.where((e) {
      final local = e.createdAt.toLocal();
      return local.year == _selectedDay.year &&
          local.month == _selectedDay.month &&
          local.day == _selectedDay.day;
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '지출 달력',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildCalendarCard(),
          Expanded(child: _buildExpenseCard()),
        ],
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
              _selectedDay = DateTime(
                selectedDay.year,
                selectedDay.month,
                selectedDay.day,
              );
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
          rowHeight: 54,
          eventLoader: (day) {
            final key = DateTime(day.year, day.month, day.day);
            final total = _dailyTotals[key];
            return total != null && total > 0 ? [total] : [];
          },
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextFormatter: (date, locale) => '${date.year}년 ${date.month}월',
            titleTextStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            leftChevronIcon: const Icon(
              Icons.chevron_left,
              color: Color(0xFF1D9E75),
            ),
            rightChevronIcon: const Icon(
              Icons.chevron_right,
              color: Color(0xFF1D9E75),
            ),
            headerPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
            weekendStyle: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
            dowTextFormatter: (date, locale) =>
                ['일', '월', '화', '수', '목', '금', '토'][date.weekday % 7],
          ),
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
            cellMargin: EdgeInsets.all(4),
            todayDecoration: BoxDecoration(
              color: Color(0xFF1D9E75),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Color(0xFF0F6E56),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(color: Colors.white, fontSize: 13),
            selectedTextStyle: TextStyle(color: Colors.white, fontSize: 13),
            weekendTextStyle: TextStyle(color: Colors.black87, fontSize: 13),
            defaultTextStyle: TextStyle(color: Colors.black87, fontSize: 13),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              final total = events.first as int;
              return Positioned(
                bottom: 2,
                child: Text(
                  _formatCompact(total),
                  style: const TextStyle(
                    fontSize: 8,
                    color: Color(0xFFE24B4A),
                  ),
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Expanded(child: _buildExpenseList()),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1D9E75),
          strokeWidth: 2,
        ),
      );
    }

    final items = _selectedExpenses;
    if (items.isEmpty) {
      return const Center(
        child: Text(
          '이날은 지출이 없어요 🎉',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (context, idx) =>
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
      itemBuilder: (context, idx) {
        final e = items[idx];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(
                cat.categoryEmoji(e.category),
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.rawInput,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.category,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                '${formatNumber(e.amount)}원',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
