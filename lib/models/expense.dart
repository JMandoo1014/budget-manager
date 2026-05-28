class Expense {
  final String id;
  final String category;
  final double amount;
  final DateTime date;
  final String? note;

  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.note,
  });
}
