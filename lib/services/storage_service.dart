import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/budget.dart';
import '../models/expense.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const _userId = 'local_user';

  static String get _url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get _anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> init() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(url: _url, anonKey: _anonKey);
  }

  Future<void> saveBudget(Budget budget, {DateTime? date}) async {
    final target = date ?? DateTime.now();
    await _client.from('budgets').upsert(
      {
        'user_id': _userId,
        'year': target.year,
        'month': target.month,
        'income': budget.income,
        'savings_goal': budget.savingsGoal,
        'savings_months': budget.savingsMonths,
        'spending_patterns': budget.spendingPatterns,
        'category_budgets': budget.categoryBudgets,
        'auto_rollover': budget.autoRollover,
      },
      onConflict: 'user_id,month,year',
    );
    await _savePreviousBudgetPrefs(budget);
  }

  Future<Budget?> getCurrentBudget() async {
    final now = DateTime.now();
    final data = await _client
        .from('budgets')
        .select()
        .eq('user_id', _userId)
        .eq('year', now.year)
        .eq('month', now.month)
        .limit(1);

    if (data.isNotEmpty) return Budget.fromJson(data.first);

    // 이번 달 예산 없음 → 지난 달 자동 이월 확인
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;

    final prevData = await _client
        .from('budgets')
        .select()
        .eq('user_id', _userId)
        .eq('year', prevYear)
        .eq('month', prevMonth)
        .limit(1);

    if (prevData.isEmpty) return null;

    final prevBudget = Budget.fromJson(prevData.first);
    if (!prevBudget.autoRollover) {
      await _savePreviousBudgetPrefs(prevBudget);
      return null;
    }

    await saveBudget(prevBudget, date: now);
    return prevBudget;
  }

  Future<void> _savePreviousBudgetPrefs(Budget budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('savings_goal', budget.savingsGoal);
    await prefs.setInt('savings_months', budget.savingsMonths);
    await prefs.setStringList('spending_patterns', budget.spendingPatterns);
    await prefs.setBool('auto_rollover', budget.autoRollover);
  }

  Future<Map<String, dynamic>?> loadPreviousBudgetPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savingsGoal = prefs.getInt('savings_goal');
    if (savingsGoal == null) return null;
    return {
      'savings_goal': savingsGoal,
      'savings_months': prefs.getInt('savings_months') ?? 12,
      'spending_patterns': prefs.getStringList('spending_patterns') ?? [],
      'auto_rollover': prefs.getBool('auto_rollover') ?? true,
    };
  }

  Future<void> updateAutoRollover(bool value) async {
    final now = DateTime.now();
    await _client
        .from('budgets')
        .update({'auto_rollover': value})
        .eq('user_id', _userId)
        .eq('year', now.year)
        .eq('month', now.month);
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }

  Future<void> saveExpense(Expense expense) async {
    await _client.from('expenses').insert({
      'user_id': _userId,
      ...expense.toJson(),
    });
  }

  Future<void> deleteMonthExpenses({int? month, int? year}) async {
    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;

    final from = DateTime(targetYear, targetMonth, 1).toIso8601String();
    final to = DateTime(targetYear, targetMonth + 1, 1).toIso8601String();

    await _client
        .from('expenses')
        .delete()
        .eq('user_id', _userId)
        .gte('created_at', from)
        .lt('created_at', to);
  }

  Future<List<Expense>> getExpenses({int? month, int? year}) async {
    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;

    final from = DateTime(targetYear, targetMonth, 1).toIso8601String();
    final to = DateTime(targetYear, targetMonth + 1, 1).toIso8601String();

    final data = await _client
        .from('expenses')
        .select()
        .eq('user_id', _userId)
        .gte('created_at', from)
        .lt('created_at', to)
        .order('created_at', ascending: false);

    return data
        .map((row) => Expense.fromJson(row))
        .toList();
  }
}
