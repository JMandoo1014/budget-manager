class Budget {
  final int income;
  final int savingsGoal;
  final int savingsMonths;
  final List<String> spendingPatterns;
  final Map<String, int> categoryBudgets;

  const Budget({
    required this.income,
    required this.savingsGoal,
    required this.savingsMonths,
    required this.spendingPatterns,
    required this.categoryBudgets,
  });

  int get totalBudget => income - savingsGoal;

  int get remainingBudget =>
      totalBudget - categoryBudgets.values.fold(0, (sum, v) => sum + v);

  Budget copyWith({
    int? income,
    int? savingsGoal,
    int? savingsMonths,
    List<String>? spendingPatterns,
    Map<String, int>? categoryBudgets,
  }) {
    return Budget(
      income: income ?? this.income,
      savingsGoal: savingsGoal ?? this.savingsGoal,
      savingsMonths: savingsMonths ?? this.savingsMonths,
      spendingPatterns: spendingPatterns ?? this.spendingPatterns,
      categoryBudgets: categoryBudgets ?? this.categoryBudgets,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'income': income,
      'savingsGoal': savingsGoal,
      'savingsMonths': savingsMonths,
      'spendingPatterns': spendingPatterns,
      'categoryBudgets': categoryBudgets,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      income: json['income'] as int,
      savingsGoal: json['savingsGoal'] as int,
      savingsMonths: json['savingsMonths'] as int,
      spendingPatterns: List<String>.from(json['spendingPatterns'] as List),
      categoryBudgets: Map<String, int>.from(json['categoryBudgets'] as Map),
    );
  }
}
