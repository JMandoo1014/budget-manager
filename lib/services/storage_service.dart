import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/budget.dart';
import '../models/expense.dart';

class StorageService {
  static const _userId = 'local_user';

  static String get _url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get _anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> init() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(url: _url, anonKey: _anonKey);
  }

  Future<void> saveBudget(Budget budget) async {
    final now = DateTime.now();
    await _client.from('budgets').insert({
      'user_id': _userId,
      'year': now.year,
      'month': now.month,
      'income': budget.income,
      'savings_goal': budget.savingsGoal,
      'savings_months': budget.savingsMonths,
      'spending_patterns': budget.spendingPatterns,
      'category_budgets': budget.categoryBudgets,
    });
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

    if (data.isEmpty) return null;
    return Budget.fromJson(data.first);
  }

  Future<void> saveExpense(Expense expense) async {
    await _client.from('expenses').insert({
      'user_id': _userId,
      ...expense.toJson(),
    });
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
