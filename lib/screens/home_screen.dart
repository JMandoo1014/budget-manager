import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/category.dart' as cat;
import '../utils/format.dart';
import '../widgets/category_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.refreshTrigger = 0});

  final int refreshTrigger;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Budget? _budget;
  List<Expense> _expenses = [];
  List<Income> _incomes = [];
  bool _isLoading = true;
  bool _hasError = false;
  DateTime? _overBudgetNotifiedDate;
  String? _aiWarning;
  bool _isLoadingWarning = false;

  final _dateFormat = DateFormat('MM/dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final now = DateTime.now();
      final budgetFuture = StorageService().getCurrentBudget();
      final expensesFuture = StorageService().getExpenses(month: now.month, year: now.year);
      final incomesFuture = StorageService().getIncomes(month: now.month, year: now.year);
      final budget = await budgetFuture;
      final expenses = await expensesFuture;
      List<Income> incomes = [];
      try {
        incomes = await incomesFuture;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _budget = budget;
          _expenses = expenses;
          _incomes = incomes;
          _isLoading = false;
        });
        _checkDailyOverBudget();
        _checkBudgetWarning();
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _checkBudgetWarning() async {
    if (_budget == null) return;

    final spentByCategory = <String, int>{};
    for (final e in _expenses) {
      spentByCategory[e.category] = (spentByCategory[e.category] ?? 0) + e.amount;
    }
    final totalSpent = spentByCategory.values.fold(0, (sum, v) => sum + v);
    final extraIncome = _incomes.fold(0, (sum, i) => sum + i.amount);
    final effectiveBudget = _budget!.totalBudget + extraIncome;
    final usedRatio = effectiveBudget > 0 ? totalSpent / effectiveBudget : 0.0;

    if (usedRatio < 0.8) return;

    setState(() => _isLoadingWarning = true);
    try {
      final warning = await AiService().generateBudgetWarning(
        remainingBudget: effectiveBudget - totalSpent,
        totalBudget: effectiveBudget,
        remainingDays: _daysLeftInt,
        spentByCategory: spentByCategory,
        budgetByCategory: _budget!.categoryBudgets,
      );
      if (mounted) setState(() { _aiWarning = warning; _isLoadingWarning = false; });
    } catch (_) {
      if (mounted) setState(() { _aiWarning = null; _isLoadingWarning = false; });
    }
  }

  void _checkDailyOverBudget() {
    if (_budget == null) return;
    final today = DateTime.now();
    if (_overBudgetNotifiedDate != null &&
        _overBudgetNotifiedDate!.year == today.year &&
        _overBudgetNotifiedDate!.month == today.month &&
        _overBudgetNotifiedDate!.day == today.day) { return; }

    final extraIncome = _incomes.fold(0, (sum, i) => sum + i.amount);
    final totalSpent = _expenses.fold(0, (sum, e) => sum + e.amount);
    final remaining = _budget!.totalBudget + extraIncome - totalSpent;
    final daysLeft = _daysLeftInt;
    if (daysLeft <= 0) return;

    final dailyBudget = remaining ~/ daysLeft;
    final todaySpent = _todaySpent;
    if (todaySpent > dailyBudget) {
      _overBudgetNotifiedDate = today;
      NotificationService().showOverBudgetNotification('오늘 하루', todaySpent - dailyBudget);
    }
  }

  String get _monthLabel => '${DateTime.now().month}월 현황';

  int get _daysLeftInt {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0).day - now.day + 1;
  }

  String get _daysLeft => '$_daysLeftInt일 남음';

  int get _todaySpent {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
            e.createdAt.year == now.year &&
            e.createdAt.month == now.month &&
            e.createdAt.day == now.day)
        .fold(0, (sum, e) => sum + e.amount);
  }

  int get _yesterdaySpent {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _expenses
        .where((e) =>
            e.createdAt.year == yesterday.year &&
            e.createdAt.month == yesterday.month &&
            e.createdAt.day == yesterday.day)
        .fold(0, (sum, e) => sum + e.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _monthLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            Text(
              _daysLeft,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _hasError
              ? _buildError()
              : _budget == null
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.primary,
                      child: _buildContent(),
                    ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 130,
            decoration: BoxDecoration(color: AppColors.skeleton, borderRadius: BorderRadius.circular(16)),
          ),
          const SizedBox(height: 20),
          Container(
            width: 70,
            height: 14,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppColors.skeleton, borderRadius: BorderRadius.circular(4)),
          ),
          ...List.generate(5, (_) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
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
            const Text(
              AppStrings.loadFailed,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
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
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💰', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              const Text(
                AppStrings.noBudget,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                '수입과 저축 목표를 입력하면\nAI가 예산을 짜드려요',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
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

  Widget _buildContent() {
    final budget = _budget!;

    final spentByCategory = <String, int>{};
    for (final e in _expenses) {
      spentByCategory[e.category] = (spentByCategory[e.category] ?? 0) + e.amount;
    }
    final totalSpent = spentByCategory.values.fold(0, (sum, v) => sum + v);
    final extraIncome = _incomes.fold(0, (sum, i) => sum + i.amount);
    final totalBudget = budget.totalBudget;
    final remaining = totalBudget + extraIncome - totalSpent;
    final effectiveBudget = totalBudget + extraIncome;
    final usedRatio = effectiveBudget > 0 ? (totalSpent / effectiveBudget).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainBudgetCard(totalBudget, totalSpent, remaining, usedRatio, extraIncome),
          _buildDailyBudgetCard(remaining, _daysLeftInt),
          if (usedRatio >= 0.8 && (_isLoadingWarning || _aiWarning != null))
            _buildAiWarningCard(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '카테고리별',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          ...budget.categoryBudgets.entries.map((entry) {
            final emoji = cat.categoryEmoji(entry.key);
            final limit = entry.value;
            final spent = spentByCategory[entry.key] ?? 0;
            final color = cat.progressColor(spent, limit);
            final categoryExpenses = _expenses.where((e) => e.category == entry.key).toList();
            return CategoryCard(
              emoji: emoji,
              name: entry.key,
              spent: spent,
              limit: limit,
              color: color,
              onTap: () => _showCategoryDetail(entry.key, emoji, spent, limit, categoryExpenses),
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildAiWarningCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isLoadingWarning ? 'AI가 분석 중...' : (_aiWarning ?? ''),
              style: const TextStyle(fontSize: 13, color: AppColors.warning, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBudgetCard(int totalBudget, int totalSpent, int remaining, double usedRatio, int extraIncome) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('남은 예산', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            '${formatNumber(remaining)}원',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          if (extraIncome > 0) ...[
            const SizedBox(height: 2),
            Text(
              '+추가수입 ${formatNumber(extraIncome)}원 포함',
              style: const TextStyle(fontSize: 11, color: AppColors.primary),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedRatio,
              minHeight: 8,
              backgroundColor: AppColors.primaryLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(usedRatio * 100).toStringAsFixed(0)}% 사용  •  총 예산 ${formatNumber(totalBudget)}원',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBudgetCard(int remaining, int daysLeft) {
    if (daysLeft <= 0) return const SizedBox.shrink();

    if (remaining <= 0) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '이번 달 예산을 ${formatNumber(-remaining)}원 초과했어요',
                style: const TextStyle(fontSize: 13, color: AppColors.danger),
              ),
            ),
          ],
        ),
      );
    }

    final dailyBudget = remaining ~/ daysLeft;
    final todaySpent = _todaySpent;
    final isOver = todaySpent > dailyBudget;
    final todayRemaining = dailyBudget - todaySpent;
    final overAmount = isOver ? todaySpent - dailyBudget : 0;
    final progress = dailyBudget > 0
        ? (todaySpent / dailyBudget).clamp(0.0, 1.0)
        : (todaySpent > 0 ? 1.0 : 0.0);
    final color = isOver ? AppColors.danger : AppColors.primary;

    final now = DateTime.now();
    final isFirstDay = now.day == 1;
    String? yesterdayText;
    if (!isFirstDay) {
      final ys = _yesterdaySpent;
      final diff = ys - todaySpent;
      if (diff > 0) {
        yesterdayText = '어제보다 ${formatNumber(diff)}원 적게 썼어요';
      } else if (diff < 0) {
        yesterdayText = '어제보다 ${formatNumber(-diff)}원 더 썼어요';
      } else {
        yesterdayText = '어제와 같은 금액을 썼어요';
      }
    }

    String? tomorrowText;
    if (isOver && daysLeft > 1) {
      final tomorrowBudget = remaining ~/ (daysLeft - 1);
      tomorrowText =
          '오늘 ${formatNumber(overAmount)}원 초과했어요. 내일부터 하루 ${formatNumber(tomorrowBudget)}원씩 써야 해요.';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘 쓸 수 있어요', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            isOver ? '${formatNumber(overAmount)}원 초과' : '${formatNumber(todayRemaining)}원',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '오늘 ${formatNumber(todaySpent)}원 사용  •  하루 ${formatNumber(dailyBudget)}원',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (yesterdayText != null) ...[
            const SizedBox(height: 3),
            Text(yesterdayText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
          if (tomorrowText != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tomorrowText,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCategoryDetail(String name, String emoji, int spent, int limit, List<Expense> expenses) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$emoji $name',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${formatNumber(spent)}원 / ${formatNumber(limit)}원',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (expenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('지출 내역이 없어요.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: expenses.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = expenses[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.rawInput,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis),
                                  Text(_dateFormat.format(e.createdAt),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('${formatNumber(e.amount)}원',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
